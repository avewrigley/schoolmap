#!/usr/bin/env perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

require CGI::Lite;
use lib "/var/www/www.schoolmap.org.uk/lib";
require School;

open( STDERR, ">>/var/www/www.schoolmap.org.uk/logs/school.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %formdata = CGI::Lite->new->parse_form_data();
my $path_info = $ENV{PATH_INFO};
my ( $school_id ) = $path_info =~ /(\d+)/;
warn map "$_ = $formdata{$_}\n", keys %formdata if %formdata;
print "Content-Type: text/html\n\n";
School->new( school_id => $school_id, %formdata )->html();

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

