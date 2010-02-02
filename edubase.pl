#!/usr/bin/perl
#set filetype=perl

use strict;
use warnings;

use DBI;
use Geo::Coordinates::OSGB qw(grid_to_ll);
use Data::Dumper;
use WWW::Mechanize;
use FindBin qw( $Bin );
use Getopt::Long;
use Pod::Usage;
use Proc::Pidfile;

my $logfile = ">$Bin/logs/edubase.log";
my $ofsted_base_url = "http://www.ofsted.gov.uk/oxcare_providers/urn_search?type=2&urn=";

my %opts;
my @opts = qw( pidfile! silent verbose );
$opts{pidfile} = 1;
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );

unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}

my $mech = WWW::Mechanize->new();
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $edubase_sth = $dbh->prepare( "SELECT PhaseOfEducation,TypeOfEstablishment,Street,Locality,Town,LLSC,EstablishmentName,URN,Postcode,Easting,Northing FROM edubase" );
$edubase_sth->execute();
my $school_sth = $dbh->prepare( "REPLACE INTO school (name, postcode, lat, lon, address, type, phase, ofsted_url, ofsted_id) VALUES (?,?,?,?,?,?,?,?,?)" );
while ( my $edubase = $edubase_sth->fetchrow_hashref )
{
    $edubase->{Postcode} =~ s/\s//g;
    my $easting = $edubase->{"Easting"};
    my $northing = $edubase->{"Northing"};
    my ( $lat, $lon ) = grid_to_ll( $easting, $northing );
    warn "$edubase->{EstablishmentName} ($edubase->{URN}) $easting $northing $edubase->{Postcode} ($lat, $lon)\n";
    my $address = join( ",", grep { defined $_ && length $_ } map $edubase->{$_}, qw( Street Locality Town LLSC ) );
    my $ofsted_url = $ofsted_base_url . $edubase->{URN};
    warn "GET $ofsted_url\n";
    my $resp = $mech->get( $ofsted_url );
    my $html = $mech->content();
    if ( $html =~ /Unique reference number/ )
    {
        warn "found on ofsted\n";
    }
    else
    {
        warn "NOT found on ofsted\n";
        $ofsted_url = undef;
    }
    $school_sth->execute( 
        $edubase->{EstablishmentName},
        $edubase->{Postcode},
        $lat,
        $lon,
        $address,
        $edubase->{TypeOfEstablishment},
        $edubase->{PhaseOfEducation},
        $ofsted_url,
        $edubase->{URN},
    );
}
