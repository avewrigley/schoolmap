#!/usr/bin/perl -T
# set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

require DBI;

open( STDERR, ">>../logs/postcodes.log" );
warn "$$ at ", scalar( localtime ), "\n";
warn "query string: $ENV{QUERY_STRING}\n";
my ( $query ) = $ENV{QUERY_STRING} =~ /query=(.*)/;
warn "query: $query\n";
print "Content-Type: text/plain\n\n";
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $sql = "SELECT code FROM postcode WHERE code LIKE '$query%' LIMIT 10";
warn "$sql\n";
my $sth = $dbh->prepare( $sql );
$sth->execute();
while ( my ( $postcode ) = $sth->fetchrow )
{
    warn "$postcode\n";
    print "$postcode\n";
}

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

