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
use LWP::Simple;
use DBI;

my $url = "http://www.freethepostcode.org/currentlist";
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $sth = $dbh->prepare( "REPLACE INTO postcode ( code, lat, lon ) VALUES ( ?,?, ? )" );

my $data = get( $url );
for ( split( "\n", $data ) )
{
    my ( $lat, $lon, $postcode ) = split( " ", $_, 3 );
    $postcode =~ s/ //;
    warn "$postcode ($lat,$lon)\n";
    $sth->execute( $postcode, $lat, $lon );
}
