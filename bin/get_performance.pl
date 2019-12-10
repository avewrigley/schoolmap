#!/usr/bin/env perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use FindBin qw( $Bin );
use LWP::Simple;
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use DBI;
use Text::CSV;
use Data::Dumper;
use File::Slurp;
use Scalar::Util qw(looks_like_number);
use YAML qw( LoadFile );
use lib "$Bin/../lib";
use vars qw( %keystages @keystages );

my $log_file = "$Bin/../logs/performance.log";
my $config_file = "$Bin/../config/schoolmap.yaml";

my %opts;
my @opts = qw( force flush keystage=s force silent pidfile! verbose );

my $school_no = 0;

my ( $dbh, $acronyms, %done );

# Main

my %config = (
    ks4 => {
        performance_url_key => "ks4_performance_url",
        score_field => 'ATT8SCR',
    },
    ks5 => {
        performance_url_key => "post16_performance_url",
        score_field => 'TALLPPE_ALEV_1618',
    },
    ks2 => {
        performance_url_key => "ks2_performance_url",
        score_field => 'TKS1AVERAGE',
    },
);

$opts{pidfile} = 1;
$opts{keystage} = "ks4";
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $keystage = $opts{keystage};
if ( not exists $config{$keystage} )
{
    die "keystage $keystage not known\n";
}
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
warn "connect to DB\n";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
unless ( $opts{verbose} )
{
    open( STDERR, ">$log_file" ) or die "can't write to $log_file\n";
}
my $config = LoadFile( $config_file );
my $performance_url_key = $config{$keystage}{performance_url_key};
my $performance_url = $config->{$performance_url_key};
my $csv_file = "$Bin/../downloads/${keystage}_performance.csv";
if ( ! -e $csv_file || $opts{force} )
{
    warn "GET $performance_url ($performance_url_key) => $csv_file\n";
    getstore( $performance_url, $csv_file );
}
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, "<:encoding(utf8)", $csv_file or die "$csv_file $!";
my $select_sql = <<EOF;
SELECT * FROM performance WHERE ofsted_id = ?
EOF
my $ssth = $dbh->prepare( $select_sql );
my $insert_sql = <<EOF;
INSERT INTO performance ( ofsted_id, $keystage) VALUES(?,?)
EOF
my $isth = $dbh->prepare( $insert_sql );
my $update_sql = <<EOF;
UPDATE performance SET $keystage = ? WHERE ofsted_id = ?
EOF
my $usth = $dbh->prepare( $update_sql );
my $header = $csv->getline( $fh );
while ( my $row = $csv->getline( $fh ) )
{
    ++$school_no;
    my %row;
    @row{@$header} = @$row;
    next unless defined($row{URN}) and length($row{URN}) and $row{URN} =~ /\S/;
    my $score_field = $config{$keystage}{score_field};
    my $score = $row{$score_field};
    if ( looks_like_number( $score ) )
    {
        warn "$school_no: $row{URN} $score\n";
        $ssth->execute( $row{URN} );
        my @row = $ssth->fetchrow();
        if ( @row )
        {
            warn "UPDATE $row{URN} SET $keystage = $score\n";
            $usth->execute( $score, $row{URN} );
        }
        else
        {
            warn "INSERT ($row{URN} $score)\n";
            $isth->execute( $row{URN}, $score );
        }
    }

}
warn "$0 ($$) finished - $school_no schools\n";
