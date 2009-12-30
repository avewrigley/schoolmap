#!/usr/bin/perl -T
# set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use lib "/var/www/www.schoolmap.org.uk/lib";
require Acronyms;
require CGI::Lite;
use JSON;

open( STDERR, ">>/var/www/www.schoolmap.org.uk/logs/acronyms.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %formdata = ( CGI::Lite->new->parse_form_data() );
warn map "$_ = $formdata{$_}\n", keys %formdata if %formdata;
# print "Content-Type: application/json\n\n";
print "Content-Type: text/plain\n\n";
my $acronyms = Acronyms->new();
if ( exists $formdata{specials} )
{
    print to_json( $acronyms->specials );
}
elsif ( exists $formdata{age_range} )
{
    print to_json( $acronyms->age_range );
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

