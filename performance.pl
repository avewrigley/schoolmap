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
use lib "$Bin/lib";
use vars qw( %types @types );

my %opts;
my @opts = qw( year=s force flush region=s la=s school=s type=s force silent pidfile! verbose );

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
my $logfile = "$Bin/logs/performance.log";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
my $csvfile = "$Bin/downloads/performance.csv";
my $config = LoadFile( "$Bin/config/schoolmap.yaml" );
my $performance_url = $config->{performance_url};
getstore( $performance_url, $csvfile );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, "<:encoding(utf8)", $csvfile or die "$csvfile: $!";
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
    my %row;
    @row{@$header} = @$row;
    warn Dumper(\%row);
    next unless defined($row{URN}) and length($row{URN});
    my @row = map {looks_like_number($_) ? $_ : 0.0} @row{qw( ATT8SCR TPUP URN )};
    warn Dumper(\@row);
    $isth->execute( @row );

}
warn "$0 ($$) finished\n";
