#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;
use Carp;
use Parallel::ForkManager;
use File::Slurp;
require URI;
require DBI;
use FindBin qw( $Bin );
use lib "$Bin/lib";
require HTML::TableContentParser;
require HTML::TableParser;
require HTML::TableExtract;
use Pod::Usage;
use Getopt::Long;
require Geo::Multimap;
use LWP::Simple;
require HTML::TreeBuilder;
require HTML::LinkExtractor;
require Proc::Pidfile;
use File::Temp qw/ tempfile /;
use Data::Dumper;
use CGI::Lite;

my %opts;
my @opts = qw( flush year=s type=s force silent pidfile! verbose );
my $region;
my $geo;
my $dbh;

sub get_text_nodes
{
    my $html = shift;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse( $html );
    my $node = $tree->elementify();
    my @tnodes;
    my @nodes = $node->look_down( @_ );
    for my $n ( @nodes )
    {
        () = $n->look_down(
            sub {
                my $element = shift;
                push( 
                    @tnodes, 
                    grep { ! ref( $_ ) && $_ =~ /\S/ } $element->content_list 
                );
            }
        );
    }
    $tree->destroy();
    return @tnodes;
}

sub get_links
{
    my $html = shift;
    my $url = shift;
    return () unless $html;
    my $re = shift;
    my $lx = new HTML::LinkExtractor();
    $lx->parse( \$html );
    my @links = @{$lx->links};
    my @hrefs = map { $_->{href} } grep { $_->{href} } @links;
    my @dhrefs = map url_decode( $_  ), @hrefs;
    my @fhrefs = grep /$re/, @dhrefs;
    my @afhrefs = map { URI->new_abs( $_, $url ) } @fhrefs;
    warn "no links match $re on $url\n" unless @afhrefs;
    return @afhrefs;
}

sub get_html
{
    my $url = shift;
    my $force = shift;
    unless ( $force || $opts{force} )
    {
        warn "$url ...\n";
        my $requested = get_requested( $url );
        if ( $requested )
        {
            warn "$url already requested at $requested\n";
            return ( undef, undef );
        }
    }
    warn "get $url\n";
    my $html = get( $url ) || warn "get $url failed";
    set_modtime( $url );
    return ( $html, $url );
}

sub create_school
{
    my $name = shift;
    my $postcode = shift;
    my $address = shift;
    my $lat = shift;
    my $lon = shift;
    die "no name" unless $name;
    die "no postcode" unless $postcode;
    $postcode = uc( $postcode );
    $postcode =~ s/[^0-9A-Z]//g;
    unless ( $lat && $lon )
    {
        ( $lat, $lon ) = $geo->coords( $postcode );
    }
    die "no lat / lon for postcode $postcode" unless $lat && $lon;
    my $select_sth = $dbh->prepare( <<SQL );
SELECT school_id FROM school WHERE name = ? AND postcode = ?
SQL
    my $school_id;
    unless ( $opts{force} )
    {
        $select_sth->execute( $name, $postcode );
        ( $school_id ) = $select_sth->fetchrow;
        return $school_id if defined $school_id;
    }
    my $replace_sth = $dbh->prepare( <<SQL );
REPLACE INTO school ( name, postcode, address ) VALUES ( ?,?,? )
SQL
    $replace_sth->execute( $name, $postcode, $address );
    $replace_sth->finish();
    $select_sth->execute( $name, $postcode );
    ( $school_id ) = $select_sth->fetchrow;
    $select_sth->finish();
    return $school_id;
}

sub add_school_type
{
    my $school_id = shift;
    my $type = shift;
    my $insert_sth = $dbh->prepare( <<SQL );
INSERT IGNORE INTO school_type ( school_id, type ) VALUES ( ?,? )
SQL
    $insert_sth->execute( $school_id, $type );
    $insert_sth->finish();
}

{
    my %result;

    sub init_report
    {
        %result = ();
    }

    sub set_modtime
    {
        my $url = shift;
        my $modtime = ( head( $url ) )[2] || 0;
        my $sql = "REPLACE INTO url ( url, modtime, requested ) VALUES ( ?, ?, NOW() )";
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $url, $modtime );
        $sth->finish;
    }

    sub get_requested
    {
        my $url = shift;
        my $sql = "SELECT requested FROM url WHERE url = ?";
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $url );
        my ( $requested ) = $sth->fetchrow;
        $sth->finish;
        return $requested;
    }
    
    sub get_modtime
    {
        my $url = shift;
        my $sql = "SELECT modtime FROM url WHERE url = ?";
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $url );
        my ( $modtime ) = $sth->fetchrow;
        $sth->finish;
        return $modtime;
    }

    sub no_update
    {
        my $url = shift;
        $result{$url} = undef;
        my $db_modtime = get_modtime( $url );
        my $http_modtime = ( head( $url ) )[2];
        return if not defined $http_modtime;
        return if not defined $db_modtime;
        if ( $db_modtime == $http_modtime )
        {
            return 1;
        }
        return;
    }

    sub update_report
    {
        my $error = shift;
        my $type = shift;
        my $url = shift;
        my $name = shift;
        my $description = $name ? "$name ($type - $region)" : $url;
        if ( $error )
        {
            warn "FAILED: $description: $error\n";
        }
        else
        {
            warn "SUCCESS: $description\n";
        }
        $result{$url} = $error;
    }

    sub print_report
    {
        warn "ALL: ", scalar( keys %result ), "\n";
        warn "SUCCESSFUL: ", scalar( grep { ! $result{$_} } keys %result ), "\n";
        warn "FAILED: ", scalar( grep { $result{$_} } keys %result ), "\n";
    }
}

sub get_name_and_url
{
    my $html = shift;
    return unless $html;
    my ( $url, $title, $name ) = $html =~ m{<a href="([^"]+)" title="([^"]+)">([^>]+)</a>};
    return ( $name, $url );
}

sub get_school_details
{
    my $html = shift;
    my %school;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse( $html );
    my $node = $tree->elementify();
    my ( $details ) = $node->look_down(
        _tag => "dl", 
        id => "details"
    );
    my @a = grep /\S/, map $_->as_text, $details->look_down(
        _tag => "dd", 
    );
    my @address;
    for ( @a )
    {
        s/\xA0/ /; # nbsp
        s/^\s*//;
        s/\s*$//;
        next unless /\S/;
        if ( /([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+)/msi )
        {
            $school{postcode} = $1;
            last;
        }
        else
        {
            push( @address, $_ );
        }
    }
    die "no postcode\n" unless $school{postcode};
    $school{address} = join( ", ", @address );
    @school{qw( lat lon )} = 
        $html =~ m{
            hlat=([-\d\.]+);
            .*?hlong=([-\d\.]+);
        }six
    ;
    return %school;
}

sub process_school_row
{
    my $row = shift;
    my $schools_url = shift;
    my $year = shift;
    my $type = shift;
    my $type_name = shift;
    my @cells = @{$row};
    my ( $name, $url ) = get_name_and_url( $cells[0] );
    return unless $name;
    warn "no school url\n" and return unless $url;
    my %school = ( year => $year, name => $name );
    my $school_url = URI->new_abs( $url, $schools_url );
    $school_url =~ s/\&amp;/&/g;
    unless ( $opts{force} )
    {
        my $sql = <<SQL;
SELECT * FROM dfes WHERE ${type_name}_url = ? AND year = ?
SQL
        my $select_sth = $dbh->prepare( $sql );
        $select_sth->execute( $school_url, $year );
        my @row = $select_sth->fetchrow;
        if ( @row )
        {
            warn "$name ($type_name - $region - $year) ALREADY SEEN\n";
            return;
        }
        else
        {
            warn "$name ($type_name - $region - $year) IS NEW\n";
        }
    }
    $school{url} = $school_url;
    return if no_update( $school{url} );
    eval {
        my $no_pupils = $cells[$type->{indexes}{no_pupils}];
        die "no no_pupils\n" unless $no_pupils;
        $school{no_pupils} = $no_pupils;
        my $aps = $cells[$type->{indexes}{aps}];
        die "no aps\n" unless $aps;
        $school{aps} = $aps;
        my ( $school_html ) = get_html( $school_url );
        %school = ( %school, get_school_details( $school_html ) );
        $school{school_id} = create_school( 
            @school{qw(name postcode address lat lon)}
        );
        add_school_type( $school{school_id}, $type->{type} );
        $type->{replace_sth}->execute( 
            @school{qw(school_id year no_pupils aps url)}
        );
    };
    update_report( $@, $type_name, $school{url}, $school{name} );
}

sub follow_links
{
    my $url = shift or die "no url\n";
    my $callback = shift;
    my @re = @_;

    if ( @re )
    {
        my $re = shift @re;
        for my $link ( get_links( get_html( $url, 1 ), $re ) )
        {
            $link =~ s/\&L=\d+/\&L=1000/;
            if ( $link =~ /(region\d+)/ )
            {
                $region = $1;
                warn "region: $region\n";
            }
            follow_links( $link, $callback, @re );
        }
    }
    else
    {
        $callback->( $url );
    }
}

sub update
{
    warn "update dfes ...\n";
    init_report();
    my %re = (
        2007 => [
            qr{/performancetables/.*/(?:region|lsc)(\d+).shtml},
            qr{/performancetables/group_07.pl\?Mode=[A-Z]+&Type=[A-Z]+&No=\d+&Base=[a-z]&F=\d+&L=\d+&Year=\d+&Phase=},
        ],
    );
    my %types = (
        post16 => { type => "post16", indexes => { no_pupils => 1, aps => 3 } },
        primary => { type => "primary", indexes => { no_pupils => 1, aps => 15 } },
        ks3 => { type => "secondary", },
        secondary => { type => "secondary", indexes => { no_pupils => 1, aps => 4 }, },
    );
    my $base = 'http://www.dfes.gov.uk/performancetables/';
    my @years = $opts{year} ? ( $opts{year} ) : keys %re;
    warn "getting data for @years\n";
    $dbh->disconnect();
    for my $year ( @years )
    {
        $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
        $geo = Geo::Multimap->new();
        my $logfile = "$Bin/logs/update.$year.log";
        open( STDERR, ">$logfile" ) or die "can't write to $logfile\n" unless $opts{verbose};
        my $y;
        if ( $year =~ /(\d\d)$/ )
        {
            $y = $1;
        }
        else
        {
            die "year $year is incorrect format\n";
        }
        my @types = qw( primary secondary ks3 post16 );
        my %type_link = (
            primary => "http://www.dfes.gov.uk/performancetables/primary_$y.shtml",
            secondary => "http://www.dfes.gov.uk/performancetables/schools_$y.shtml",
            post16 => "http://www.dfes.gov.uk/performancetables/16to18_$y.shtml",
            ks3 => "http://www.dfes.gov.uk/performancetables/ks3_$y.shtml",
        );
        @types = $opts{type} ?  ( $opts{type} ) : @types;
        for my $type ( @types )
        {
            my $type_link = $type_link{$type};
            my @keys = (
                "pupils_$type",
                "average_$type",
                "${type}_url",
            );
            my $replace_sql = 
                "REPLACE INTO dfes (" . 
                join( ",", 'school_id', 'year', @keys ) . ") " .
                "VALUES (" . join( ",", map "?", 'school_id', 'year', @keys ) . ")"
            ;
            $types{$type}{replace_sth} = $dbh->prepare( $replace_sql );
            my $callback = sub {
                my $url = shift;
                warn "GET SCHOOLS TABLE\n";
                my ( $html ) = get_html( $url, 1 );
                return unless $html;
                my $te = HTML::TableExtract->new( keep_html => 1 );
                $te->parse( $html );
                my ( $table ) = $te->tables;
                if ( $table )
                {
                    for my $row ( $table->rows )
                    {
                        process_school_row( $row, $url, $year, $types{$type}, $type );
                    }
                }
                else
                {
                    warn "can't find able in $url\n";
                }
            };
            follow_links( $type_link, $callback, @{$re{$year}} );
        }
        $dbh->disconnect();
        print_report();
    }
    warn "all done\n";
    warn "update dfes finished\n";
};

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
if ( $opts{year} )
{
    die "year $opts{year} is not valid\n" unless $opts{year} =~ /^\w{4}$/;
}
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}

if ( $opts{flush} )
{
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    for my $table ( qw( dfes ofsted isi school school_type url ) )
    {
        warn "flush $table\n";
        $dbh->do( "DELETE FROM $table" );
    }
    $dbh->disconnect();
    exit;
update
}

my $logfile = "$Bin/logs/update.log";
open( STDERR, ">$logfile" ) or die "can't write to $logfile\n" unless $opts{verbose};
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
$geo = Geo::Multimap->new();
update();
$dbh->disconnect();
warn "$0 ($$) finished\n";

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

