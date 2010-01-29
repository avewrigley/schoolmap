#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use Text::CSV;
use FindBin qw( $Bin );
use DBI;

my $csv = Text::CSV->new();
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $sth = $dbh->prepare( "SELECT school.ofsted_id, school.dcsf_id, school.name, ofsted.type,postcode.lon,postcode.lat FROM postcode,ofsted,school LEFT JOIN school_list ON (school.ofsted_id = school_list.URN) WHERE URN IS NULL && school.postcode = postcode.code AND school.ofsted_id = ofsted.ofsted_id ORDER BY school.ofsted_id" );
$sth->execute();
$csv->combine( "URN", "LA (code)", "EstablishmentNumber", "Name", "Type", "Longitude", "Latitude" );
print $csv->string, "\n";
while ( my @school = $sth->fetchrow )
{
    splice( @school, 1, 1, $school[1] ? $school[1] =~ /(\d{3})(\d{4})/ : ("","" ) );
    $csv->combine( @school );
    print $csv->string, "\n";
}
