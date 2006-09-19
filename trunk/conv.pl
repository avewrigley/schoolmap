#!/usr/bin/env perl

use strict;
use warnings;

use Carp;

use DBI;
use FindBin qw( $Bin );

my $dbh1 = DBI->connect( "DBI:CSV:f_dir=$Bin/csv" )
    or die "Cannot connect: " . $DBI::errstr
;
my $dbh2 = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap' )
    or die "Cannot connect: " . $DBI::errstr
;
my $sth1 = $dbh1->prepare( "SELECT * FROM uk.pc.ll.csv" );
$sth1->execute();
my $sth2 = $dbh2->prepare( "INSERT INTO postcode ( code, lat, lon ) VALUES ( ?, ?, ? )" );
while ( my $pc = $sth1->fetchrow_hashref )
{
    warn join( ",", map "$_ = $pc->{$_}", keys %$pc ), "\n";
    my %pc = %$pc;
    $sth2->execute( @pc{qw{code lat long}} );
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


#------------------------------------------------------------------------------
#
# True ...
#
#------------------------------------------------------------------------------

1;

