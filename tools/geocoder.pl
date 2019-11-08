#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
require Geo::Coder::OpenCage;

my $api_key = "fe2b2d1377b646c4931bd791051f91d9";
my $Geocoder = Geo::Coder::OpenCage->new(api_key => $api_key);
my $result = $Geocoder->geocode(location => shift);

die Dumper $result;

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

