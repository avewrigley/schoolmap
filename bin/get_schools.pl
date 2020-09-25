#!/usr/bin/env perl
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
use LWP::UserAgent;
use Gzip::Faster;
use File::Slurp;
use Text::CSV;
use YAML qw( LoadFile );
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use Data::Dumper;
use lib "$Bin/../lib";
require Schools;

my %opts;
my @opts = qw( force! silent pidfile! verbose );
my $school_no = 0;
my $failed = 0;
my $success = 0;
my $log_file = "$Bin/../logs/get_schools.log";
my $config_file = "$Bin/../config/schoolmap.yaml";
my $csv_file = "$Bin/../downloads/schools.csv";
my $template_dir = "$Bin/../templates";

my ( $dbh, $sc );

sub get
{
    my ($ua, $url, $path) = @_;
    my $response = $ua->get($url);
    if ($response->is_success ()) {
        my $content_encoding = $response->header ('Content-Encoding');
        my $text = $response->content;
        if ($content_encoding) {
            if ($content_encoding eq 'gzip') {
                my $uncompressed = gunzip ($text);
                $text = $uncompressed;
            }
        }
        write_file( $path, $text );
    }
    else {
        die "GET '$url' failed: ", $response->status_line, "\n";
    }
}

sub get_address
{
    my $row = shift;
    my $address = $row->{Street};
    for my $f ( qw( Locality Address3 Town County ) )
    {
        $address = "$address, $row->{$f}" if $row->{$f};
    }
    return $address;
}

sub update_school
{
    my %row = @_;

    my %school = ( 
        name => $row{"EstablishmentName"},
        ofsted_id => $row{"URN"},
        url => "http://www.ofsted.gov.uk/inspection-reports/find-inspection-report/provider/ELS/" . $row{"URN"},
        type => $row{"TypeOfEstablishment (name)"},
        phase => $row{"PhaseOfEducation (name)"},
        address => get_address( \%row ),
        postcode => $row{"Postcode"},
    );
    ++$school_no;
    eval {
        die "no type\n" unless $school{type};
        die "no url\n" unless $school{url};
        my $school = $sc->get_school( $school{ofsted_id} );
        if ( $school )
        {
            %school = ( %$school, %school );
        }
        $sc->create_school( %school );
    };
    if ( $@ )
    {
        warn "$school_no: $school{url} FAILED: $@\n";
        warn Dumper(\%school);
        $failed++;
    }
    else
    {
        # warn "$school_no: $school{url} SUCCESS\n";
        $success++;
    }
}

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
unless ( $opts{verbose} )
{
    open( STDERR, ">", $log_file ) or die "can't write to $log_file\n";
}
my $config = LoadFile( $config_file );
if ( ! -e $csv_file || $opts{force} )
{
    my $csvurl = $config->{schools_url};
    warn "GET $csvurl => $csv_file\n";
    my $ua = LWP::UserAgent->new ();
    get( $ua, $csvurl, $csv_file );
}
$sc = Schools->new( config_file => $config_file, template_dir => $template_dir );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
# open my $fh, "<:encoding(utf8)", $csv_file or die "$csv_file $!";
open my $fh, "<", $csv_file or die "$csv_file $!";
my $header = $csv->getline( $fh );
my $nschools = `wc -l < $csv_file` - 1;
my $i = 0;
while ( my $row = $csv->getline( $fh ) )
{
    my %row;
    @row{@$header} = @$row;
    update_school( %row );
    $i++;
    print STDERR "$i / $nschools\r";
}
warn "$0 ($$) finished - $school_no schools, $success success, $failed failed\n";
