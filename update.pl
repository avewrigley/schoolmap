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
use File::Slurp;
require URI;
require DBI;
use FindBin qw( $Bin );
use lib "$Bin/lib";
use Pod::Usage;
use Getopt::Long;
require Geo::Multimap;
use LWP::Simple;
require HTML::TreeBuilder;
require HTML::LinkExtractor;
require HTML::TableExtract;
require Proc::Pidfile;
use File::Temp qw/ tempfile /;
use Data::Dumper;
use CGI::Lite;

my %opts;
my @opts = qw( flush type=s silent pidfile! verbose );
my $year = "2007";
my $region;
my $geo;
my $dbh;
my @types = qw( primary secondary ks3 post16 );

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
    my $requested = get_requested( $url );
    if ( $requested )
    {
        # warn "$url already requested at $requested\n";
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
    my $insert_sth = $dbh->prepare( <<SQL );
REPLACE INTO school ( name, postcode, address ) VALUES ( ?,?,? )
SQL
    $insert_sth->execute( $name, $postcode, $address );
    $insert_sth->finish();
    $select_sth->execute( $name, $postcode );
    ( $school_id ) = $select_sth->fetchrow;
    $select_sth->finish();
    return $school_id;
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
    unless ( $details )
    {
        die "no details DL\n";
    }
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
    $tree = $tree->delete;
    return %school;
}

sub process_school_row
{
    my $row = shift;
    my $schools_url = shift;
    my $type = shift;
    my $type_name = shift;
    my @cells = @{$row};
    my ( $name, $url ) = get_name_and_url( $cells[0] );
    return unless $name;
    warn "no school url\n" and return unless $url;
    my %school = ( name => $name );
    my $school_url = URI->new_abs( $url, $schools_url );
    $school_url =~ s/\&amp;/&/g;
    my $sql = <<SQL;
SELECT * FROM dfes WHERE ${type_name}_url = ? AND average_${type_name} <> 0
SQL
    my $select_sth = $dbh->prepare( $sql );
    $select_sth->execute( $school_url );
    my @row = $select_sth->fetchrow;
    if ( @row )
    {
        warn "$school_url $name ($type_name - $region ) ALREADY SEEN\n";
        return;
    }
    else
    {
        warn "$school_url $name ($type_name - $region ) IS NEW\n";
    }
    $school{url} = $school_url;
    return if no_update( $school{url} );
    eval {
        my $no_pupils = $cells[$type->{indexes}{no_pupils}];
        warn "no_pupils: $no_pupils\n";
        die "no no_pupils\n" unless $no_pupils;
        die "non-numeric no_pupils ($no_pupils)\n" if $no_pupils =~ /\D/;
        $school{no_pupils} = $no_pupils;
        my $aps = $cells[$type->{indexes}{aps}];
        warn "aps: $aps\n";
        die "no aps\n" unless $aps;
        $school{aps} = $aps;
        die "non-numeric aps ($aps)\n" unless $aps =~ /^[\d.]+$/;
        my ( $school_html ) = get_html( $school_url );
        die "no HTML for $school_url\n" unless $school_html;
        %school = ( %school, get_school_details( $school_html ) );
        $school{school_id} = create_school( 
            @school{qw(name postcode address lat lon)}
        );
        $type->{select_sth}->execute( $school{school_id} );
        if ( $type->{select_sth}->fetchrow )
        {
            warn "school $school{school_id} exists ... update\n";
            $type->{update_sth}->execute(
                @school{qw(no_pupils aps url school_id)}
            );
        }
        else
        {
            warn "school $school{school_id} is new ... insert\n";
            my @values = @school{qw(school_id no_pupils aps url)};
            $type->{insert_sth}->execute( @values );
        }
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
            # this avoids paging of schools table ...
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
    my @re = (
        qr{/performancetables/.*/(?:region|lsc)(\d+).shtml},
        qr{/performancetables/group_07.pl\?Mode=[A-Z]+&Type=[A-Z]+&No=\d+&Base=[a-z]&F=\d+&L=\d+&Year=\d+&Phase=},
    );
    my %types = (
        post16 => { type => "post16", indexes => { no_pupils => 1, aps => 4 } },
        primary => { type => "primary", indexes => { no_pupils => 1, aps => 15 } },
        ks3 => { type => "secondary", indexes => { no_pupils => 1, aps => 15 } },
        secondary => { type => "secondary", indexes => { no_pupils => 1, aps => 15 }, },
    );
    my $base = 'http://www.dfes.gov.uk/performancetables/';
    $dbh->disconnect();
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $geo = Geo::Multimap->new();
    my ( $y ) = $year =~ /^\d\d(\d\d)$/;
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
        my $select_sql = "SELECT school_id FROM dfes WHERE school_id = ?";
        $types{$type}{select_sth} = $dbh->prepare( $select_sql );
        my $update_sql = 
            "UPDATE dfes SET " . 
            join( ",", map "$_=?", @keys ) . 
            " WHERE school_id = ?"
        ;
        $types{$type}{update_sth} = $dbh->prepare( $update_sql );
        $types{$type}{insert_sql} = 
            "INSERT INTO dfes (" . 
            join( ",", 'school_id', @keys ) . ") " .
            "VALUES (" . join( ",", map "?", 'school_id', @keys ) . ")"
        ;
        $types{$type}{insert_sth} = $dbh->prepare( $types{$type}{insert_sql} );
        my $callback = sub {
            my $url = shift;
            my ( $html ) = get_html( $url, 1 );
            return unless $html;
            my $te = HTML::TableExtract->new( keep_html => 1 );
            $te->parse( $html );
            my ( $table ) = $te->tables;
            if ( $table )
            {
                for my $row ( $table->rows )
                {
                    process_school_row( $row, $url, $types{$type}, $type );
                }
            }
            else
            {
                warn "can't find able in $url\n";
            }
        };
        follow_links( $type_link, $callback, @re );
    }
    $dbh->disconnect();
    print_report();
    warn "all done\n";
    warn "update dfes finished\n";
};

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}

if ( $opts{flush} )
{
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    for my $table ( qw( dfes ofsted isi school url ) )
    {
        warn "flush $table\n";
        $dbh->do( "DELETE FROM $table" );
    }
    $dbh->disconnect();
}

my $logfile = $opts{type} ? "$Bin/logs/update.$opts{type}.log" : "$Bin/logs/update.log";
unless ( $opts{verbose} )
{
    open( STDERR, ">>$logfile" ) or die "can't write to $logfile\n";
}
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

