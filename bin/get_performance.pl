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
use vars qw( %types @types );

my $log_file = "$Bin/../logs/performance.log";
my $csv_file = "$Bin/../downloads/performance.csv";
my $config_file = "$Bin/../config/schoolmap.yaml";

my %opts;
my @opts = qw( year=s force flush region=s la=s school=s type=s force silent pidfile! verbose );

my $school_no = 0;

my ( $dbh, $acronyms, %done );

# Main

$opts{pidfile} = 1;
$opts{year} = 2009;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
unless ( $opts{verbose} )
{
    open( STDERR, ">$log_file" ) or die "can't write to $log_file\n";
}
my $config = LoadFile( $config_file );
my $performance_url = $config->{performance_url};
getstore( $performance_url, $csv_file );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, "<:encoding(utf8)", $csv_file or die "$csv_file $!";
my $insert_sql = <<EOF;
REPLACE INTO performance (
    average_secondary,
    pupils_secondary,
    ofsted_id
) VALUES(?,?,?)
EOF
my $isth = $dbh->prepare( $insert_sql );
my $header = $csv->getline( $fh );
while ( my $row = $csv->getline( $fh ) )
{
    ++$school_no;
    my %row;
    @row{@$header} = @$row;
    next unless defined($row{URN}) and length($row{URN});
    my @row = map {looks_like_number($_) ? $_ : 0.0} @row{qw( ATT8SCR TPUP URN )};
    warn "$school_no: $row{URN} SUCCESS\n";
    $isth->execute( @row );

}
warn "$0 ($$) finished - $school_no schools\n";
