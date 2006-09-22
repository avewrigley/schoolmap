#!/usr/bin/perl -T
# set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use lib "../lib";
require Schools;
require CGI::Lite;

open( STDERR, ">>../logs/schools.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %formdata = CGI::Lite->new->parse_form_data();
warn map "$_ = $formdata{$_}\n", keys %formdata if %formdata;
my $ofsted = Schools->new( %formdata );
my $xml;
if ( $formdata{types} )
{
    print "Content-Type: text/plain\n\n";
    $xml = $ofsted->types();
}
elsif ( $formdata{count} )
{
    print "Content-Type: text/plain\n\n";
    $xml = $ofsted->schools_count();
}
else
{
    print "Content-Type: text/xml\n\n";
    $xml = $ofsted->schools_xml();
}
# warn $xml;
print $xml;

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

