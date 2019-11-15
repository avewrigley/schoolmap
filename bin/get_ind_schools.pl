#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use WWW::Mechanize;
use HTML::Entities;
use FindBin qw( $Bin );
use LWP::Simple;
use Text::CSV;
use YAML qw( LoadFile );
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use DBI;
use Data::Dumper;
use lib "$Bin/lib";
require CreateSchool;

my %opts;
my @opts = qw( force! silent pidfile! verbose phase=s );

my ( $dbh, $sc );

sub get_address
{
    my $url = shift;

    my $mech = WWW::Mechanize->new();
    warn "GET $url\n";
    my $resp = $mech->get( $url );
    my $html = $mech->content();
    die "no HTML\n" unless $html;
    my @address = grep /\w/, map decode_entities( $_ ), $html =~ m{<address.*?>(.*?)</address>}gsim;
    return join( ",", @address );
}

sub update_school
{
    my %school = @_;

    warn "$school{name} ($school{type} - $school{phase})\n";
    return if $opts{phase} && $school{phase} ne $opts{phase};
    eval {
        die "no type\n" unless $school{type};
        die "no url\n" unless $school{url};
        my $school = $sc->get_school( $school{ofsted_id} );
        if ( $school )
        {
            %school = ( %$school, %school );
        }
        if ( ! $school{address} ) {
            $school{address} = get_address( $school{url} );
            print Dumper( \%school );
        }
        $sc->create_school( %school );
    };
    if ( $@ )
    {
        die "$school{url} FAILED: $@\n";
    }
    else
    {
        warn "$school{url} SUCCESS\n";
    }
}

# Main

$opts{pidfile} = 1;
$opts{force} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
my $config = LoadFile( "$Bin/config/schoolmap.yaml" );
my $csvurl = $config->{independent_schools_url};
my $csvfile = "$Bin/downloads/independent_schools.csv";
my $logfile = "$Bin/logs/get_independent_schools.log";
getstore( $csvurl, $csvfile );
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
$sc = CreateSchool->new( dbh => $dbh );
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
# open my $fh, "<:encoding(utf8)", $csvfile or die "$csvfile: $!";
open my $fh, "<", $csvfile or die "$csvfile: $!";
my $title = $csv->getline( $fh );
my $blank = $csv->getline( $fh );
my $header = $csv->getline( $fh );
my $i = 0;
while ( my $row = $csv->getline( $fh ) )
{
    my %row;
    @row{@$header} = @$row;
    my %school = ( 
        name => $row{"School name"},
        ofsted_id => $row{"URN"},
        url => "https://reports.ofsted.gov.uk/provider/27/$row{URN}",
        type => $row{"Type of education"},
        phase => "Independent",
        postcode => $row{"Postcode"},
    );
    update_school( %school );
    warn ++$i;
}
warn "$0 ($$) finished\n";
