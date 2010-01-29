#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use FindBin qw( $Bin );
use DBI;

my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $sth = $dbh->prepare( "INSERT INTO ofsted_dcsf ( ofsted_id, dcsf_id ) VALUES ( ?, ? )" );
open( FH, "ofsted_dcsf.csv" ) or die $!;
while ( <FH> )
{
    chomp;
    my ( $urn, $la, $en ) = split( "," );
    print "$urn - $la - $en\n";
    if ( defined $urn && defined $la && defined $en )
    {
        $sth->execute( $urn, "$la$en" );
    }
}
