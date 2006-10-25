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

# open( STDERR, ">logs/sp.log" );
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $ssth = $dbh->prepare( "SELECT * FROM postcode" );
my $usth = $dbh->prepare( "UPDATE postcode SET location = GeomFromText( ? ) WHERE code = ?" );
$ssth->execute();
while ( my $school = $ssth->fetchrow_hashref )
{
    warn "$school->{code}\n";
    die "no x" unless defined $school->{x};
    die "no y" unless defined $school->{y};
    $usth->execute( "POINT($school->{x} $school->{y})", $school->{code} );
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

