#!/usr/bin/perl
# set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../lib";
require Schools;
require CGI::Lite;

my %mimetype = (
    xml => "text/xml",
    georss => "application/rss+xml",
    kml => "application/vnd.google-earth.kml+xml",
    json => "application/json",
    # json => "text/plain",
);
open( STDERR, ">>/var/www/www.schoolmap.org.uk/logs/schools.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %formdata = ( format => "json", CGI::Lite->new->parse_form_data() );
warn map "$_ = $formdata{$_}\n", keys %formdata;
if ( exists $formdata{types} )
{
    # print "Content-Type: application/json\n\n";
    print "Content-Type: text/plain\n\n";
    Schools->new( %formdata )->types();
    exit;
}
my $mimetype = $mimetype{$formdata{format}};
print "Content-Type: $mimetype\n\n";
if ( $formdata{format} eq 'json' )
{
    Schools->new( %formdata )->json();
}
else
{
    Schools->new( %formdata )->xml();
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

