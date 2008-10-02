#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

my $api_key = "ABQIAAAAzvdwQCWLlw5TXpo7sNhCSRTpDCCGWHns9m2oc9sQQ_LCUHXVlhS7v4YbLZCNgHXnaepLqcd-J0BBDw";
use Geo::Coder::Google;
my $geocoder = Geo::Coder::Google->new(
    apikey => $api_key,
    host => "maps.google.co.uk",
);
warn "geocoder: $geocoder\n";
my $location = $geocoder->geocode( 
    location => shift
);
die Dumper $location;

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

