#!/usr/bin/perl -T
# set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use lib '../lib';
require Geo::Postcode;
require CGI::Lite;

open( STDERR, ">>../logs/postcode.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %form = CGI::Lite->new->parse_form_data();
print "Content-Type: text/xml\n\n<data>";
if ( $form{postcode} )
{
    my $geo = Geo::Postcode->new();
    my %loc = $geo->find( $form{postcode} );
    if ( %loc )
    {
        print "<coords ", map( "$_=\"$loc{$_}\" ", qw( x y lat lon code ) ), "/>";
    }
}
print "</data>";

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

