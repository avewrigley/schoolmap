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
require CreateSchool;
use File::Temp qw/ tempfile /;
use Data::Dumper;
use CGI::Lite;

my %opts;
my @opts = qw( flush type=s la=s region=i silent pidfile! verbose );
my $year = "2007";
my $region;
my $la;
my $geo;
my ( $sc, $dbh );
my @types = qw( primary secondary ks3 post16 );
my %result;

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
    warn "get $url\n";
    my $html = get( $url ) || warn "get $url failed";
    return ( $html, $url );
}

sub update_report
{
    my $error = shift;
    my $type = shift;
    my $url = shift;
    my $name = shift;
    my $description = $name ? "$name ($type - $region - $la)" : $url;
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
    warn "POSTCODE: $school{postcode}\n";
    $school{address} = join( ", ", @address );
    warn "ADDRESS: $school{address}\n";
    @school{qw( lat lon )} = 
        $html =~ m{
            hlat=([-\d\.]+);
            .*?hlong=([-\d\.]+);
        }six
    ;
    warn "LAT/LON: ", join( ",", @school{qw(lat lon)} ), "\n";
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
    my $school_info = $cells[0];
    return unless $school_info;
    my ( $url, $title, $name ) = $school_info =~ m{<a href="([^"]+)" title="([^"]+)">([^>]+)</a>};
    warn "no school url\n" and return unless $url;
    warn "no school name\n" and return unless $name;
    my %dfes_results = ( name => $name );
    my $school_url = URI->new_abs( $url, $schools_url );
    $school_url =~ s/\&amp;/&/g;
    $dfes_results{url} = $school_url;
    eval {
        my ( $dfes_id ) = $school_url =~ /No=(\d+)/;
        die "no dfes_id\n" unless $dfes_id;
        my $no_pupils = $cells[$type->{indexes}{no_pupils}];
        die "no no_pupils\n" unless $no_pupils;
        die "non-numeric no_pupils\n" if $no_pupils =~ /\D/;
        $dfes_results{no_pupils} = $no_pupils;
        my $aps = $cells[$type->{indexes}{aps}];
        die "no aps\n" unless $aps;
        die "non-numeric aps\n" unless $aps =~ /^[\d.]+$/;
        $dfes_results{aps} = $aps;
        $dfes_results{dfes_id} = $dfes_id;
        $type->{select_sth}->execute( $dfes_id );
        my $row = $type->{select_sth}->fetchrow_hashref;
        if ( $row )
        {
            if ( 
                defined ( $row->{"average_$type_name"} ) &&
                $row->{"average_$type_name"} == $aps &&
                defined ( $row->{"pupils_$type_name"} ) &&
                $row->{"pupils_$type_name"} == $no_pupils
            )
            {
                warn "NO CHANGE for $dfes_id\n";
            }
            else
            {
                warn "UPDATE $dfes_id\n";
                $type->{update_sth}->execute(
                    @dfes_results{qw(no_pupils aps url dfes_id)}
                );
            }
        }
        else
        {
            warn "INSERT $dfes_results{dfes_id}\n";
            my @values = @dfes_results{qw(dfes_id no_pupils aps url)};
            $type->{insert_sth}->execute( @values );
        }
        my $select_sql = "SELECT * FROM school WHERE dfes_id = ?";
        my $select_sth = $dbh->prepare( $select_sql );
        $select_sth->execute( $dfes_id );
        $row = $select_sth->fetchrow_hashref();
        if ( $row )
        {
            warn "$dfes_id already in school table\n";
        }
        else
        {
            warn "ADD $dfes_id to schools table\n";
            my ( $school_html ) = get_html( $school_url );
            die "no HTML for $school_url\n" unless $school_html;
            my %school = get_school_details( $school_html );
            $school{dfes_id} = $dfes_id;
            $school{name} = $name;
            $sc->create_school( 'dfes_id', %school );
        }
    };
    update_report( $@, $type_name, $dfes_results{url}, $dfes_results{name} );
}

sub follow_links
{
    my $url = shift or die "no url\n";
    my $callback = shift;
    my @re = @_;

    if ( @re )
    {
        my $re = shift @re;
        LINK: for my $link ( get_links( get_html( $url, 1 ), $re ) )
        {
            # this avoids paging of schools table ...
            $link =~ s/\&L=\d+/\&L=1000/;
            if ( $link =~ /region(\d+)/ )
            {
                $region = $1;
                if ( $region )
                {
                    warn "region: $region\n";
                    if ( $opts{region} && $opts{region} ne $region )
                    {
                        next LINK;
                    }
                }
            }
            if ( $link =~ /No=(\d+)/ )
            {
                $la = $1;
                if ( $la )
                {
                    warn "la: $la\n";
                    if ( $opts{la} && $opts{la} ne $la )
                    {
                        next LINK;
                    }
                }
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
        $types{$type}{select_sql} = 
            "SELECT * FROM dfes WHERE dfes_id = ?"
        ;
        $types{$type}{select_sth} = $dbh->prepare( $types{$type}{select_sql} );
        my $update_sql = 
            "UPDATE dfes SET " . 
            join( ",", map "$_=?", @keys ) . 
            " WHERE dfes_id = ?"
        ;
        $types{$type}{update_sth} = $dbh->prepare( $update_sql );
        $types{$type}{insert_sql} = 
            "INSERT INTO dfes (" . 
            join( ",", 'dfes_id', @keys ) . ") " .
            "VALUES (" . join( ",", map "?", 'dfes_id', @keys ) . ")"
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

$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
$sc = CreateSchool->new( dbh => $dbh );
if ( $opts{flush} )
{
    for my $table ( qw( dfes ) )
    {
        warn "flush $table\n";
        $dbh->do( "DELETE FROM $table" );
    }
}

my $logfile = $opts{type} ? "$Bin/logs/dfes.$opts{type}.log" : "$Bin/logs/dfes.log";
unless ( $opts{verbose} )
{
    open( STDERR, ">>$logfile" ) or die "can't write to $logfile\n";
}
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
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

