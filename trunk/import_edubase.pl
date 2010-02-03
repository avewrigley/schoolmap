#!/usr/bin/perl
#set filetype=perl

use strict;
use warnings;

use Text::CSV;
use Data::Dumper;
use Geo::Coordinates::OSGB qw(grid_to_ll);
use WWW::Mechanize;
use Getopt::Long;
use Pod::Usage;
use Proc::Pidfile;
use FindBin qw( $Bin );
use DBI;

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
my $cvsfile = shift or die "usage: $0 <csvfile>\n";

my $mech = WWW::Mechanize->new();
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $dcsf_sth = $dbh->prepare( "SELECT dcsf_id FROM school WHERE ofsted_id = ?" );
my $school_sth = $dbh->prepare( "REPLACE INTO school (name, postcode, lat, lon, address, type, phase, ofsted_url, ofsted_id, dcsf_id) VALUES (?,?,?,?,?,?,?,?,?,?)" );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, "<:encoding(utf8)", $cvsfile or die "$cvsfile: $!";
my $header = $csv->getline( $fh );
while ( my $row = $csv->getline( $fh ) )
{
    my %row;
    @row{@$header} = @$row;
    warn "$row{EstablishmentName}\n";
    add_school( \%row );
}

sub add_school
{
    my $edubase = shift;
    for my $k1 ( keys %$edubase )
    {
        my $k2 = $k1;
        $k2 =~ s/ \(name\)//;
        $edubase->{$k2} = delete $edubase->{$k1};
    }
    for ( qw( Postcode Easting Northing EstablishmentName URN TypeOfEstablishment PhaseOfEducation ) )
    {
        warn "No $_\n" and return unless $edubase->{$_};
    }
    $dcsf_sth->execute( $edubase->{URN} );
    ( $edubase->{dcsf_id} ) = $dcsf_sth->fetchrow();
    $edubase->{Postcode} =~ s/\s//g;
    my $easting = $edubase->{Easting};
    my $northing = $edubase->{Northing};
    ( $edubase->{lat}, $edubase->{lon} ) = grid_to_ll( $easting, $northing );
    warn "$edubase->{EstablishmentName} ($edubase->{URN}, $edubase->{dcsf_id}) $easting $northing $edubase->{Postcode} ($edubase->{lat}, $edubase->{lon})\n";
    $edubase->{address} = join( ",", grep { defined $_ && length $_ } map $edubase->{$_}, qw( Street Locality Town LLSC ) );
    $edubase->{ofsted_url} = $ofsted_base_url . $edubase->{URN};
    # warn "GET $edubase->{ofsted_url}\n";
    # my $resp = $mech->get( $edubase->{ofsted_url} );
    # my $html = $mech->content();
    # if ( $html =~ /Unique reference number/ )
    # {
    # warn "found on ofsted\n";
    # }
    # else
    # {
    # warn "NOT found on ofsted\n";
    # $edubase->{ofsted_url} = undef;
    # }
    $school_sth->execute( 
        $edubase->{EstablishmentName},
        $edubase->{Postcode},
        $edubase->{lat},
        $edubase->{lon},
        $edubase->{address},
        $edubase->{TypeOfEstablishment},
        $edubase->{PhaseOfEducation},
        $edubase->{ofsted_url},
        $edubase->{URN},
    );
}
