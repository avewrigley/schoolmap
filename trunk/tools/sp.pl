#!/usr/bin/env perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use DBI;
use lib "lib";
use Geo::Multimap;

# open( STDERR, ">logs/sp.log" );
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $ssth = $dbh->prepare( "SELECT school_id, postcode FROM school" );
my $usth = $dbh->prepare( "UPDATE school SET postcode = ? WHERE school_id = ?" );
my $geo = Geo::Multimap->new();
$ssth->execute();
while ( my $loc = $ssth->fetchrow_hashref )
{
    my $postcode = uc( $loc->{postcode} );
    $postcode =~ s/[^0-9A-Z]//g;
    warn "$loc->{postcode} -> $postcode for $loc->{school_id}\n";
    $usth->execute( $postcode, $loc->{school_id} );
}
$ssth->finish();
$usth->finish();
$dbh->disconnect();

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

