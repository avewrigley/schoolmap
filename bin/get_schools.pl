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
use LWP::Simple;
use Text::CSV;
use YAML qw( LoadFile );
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use Data::Dumper;
use lib "$Bin/../lib";
require Schools;

my %opts;
my @opts = qw( force! silent pidfile! verbose phase=s );
my $school_no = 0;
my $failed = 0;
my $success = 0;
my $log_file = "$Bin/../logs/get_schools.log";
my $config_file = "$Bin/../config/schoolmap.yaml";
my $csv_file = "$Bin/../downloads/schools.csv";
my $template_dir = "$Bin/../templates";

my ( $dbh, $sc );

sub get_address
{
    my $url = shift;

    my $mech = WWW::Mechanize->new();
    my $resp = $mech->get( $url );
    my $html = $mech->content();
    die "no HTML\n" unless $html;
    my @address = grep /\w/, map decode_entities( $_ ), $html =~ m{<address.*?>(.*?)</address>}gsim;
    return join( ",", @address );
}

sub update_school
{
    my %school = @_;

    return if $opts{phase} && $school{phase} ne $opts{phase};
    ++$school_no;
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
        }
        $sc->create_school( %school );
    };
    if ( $@ )
    {
        warn "$school_no: $school{url} FAILED: $@\n";
        $failed++;
    }
    else
    {
        warn "$school_no: $school{url} SUCCESS\n";
        $success++;
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
unless ( $opts{verbose} )
{
    open( STDERR, ">$log_file" ) or die "can't write to $log_file\n";
}
my $config = LoadFile( $config_file );
my $csvurl = $config->{schools_url};
my $code = getstore( $csvurl, $csv_file );
$sc = Schools->new( config_file => $config_file, template_dir => $template_dir );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
# open my $fh, "<:encoding(utf8)", $csv_file or die "$csv_file $!";
open my $fh, "<", $csv_file or die "$csv_file $!";
my $header = $csv->getline( $fh );
while ( my $row = $csv->getline( $fh ) )
{
    my %row;
    @row{@$header} = @$row;
    my %school = ( 
        name => $row{"School name"},
        ofsted_id => $row{"URN"},
        url => $row{"Web Link"},
        type => $row{"Type of education"},
        phase => $row{"Phase of education"},
        postcode => $row{"Postcode"},
    );
    update_school( %school );
}
warn "$0 ($$) finished - $school_no schools, $success success, $failed failed\n";
