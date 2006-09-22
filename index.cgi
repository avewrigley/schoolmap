#!/usr/bin/perl -T
# set filetype=perl

use strict;
use warnings;
use CGI::Lite;
use Template;

open( STDERR, ">>logs/index.log" );
warn "$$ at ", scalar( localtime ), "\n";
print "Content-Type: text/html\n\n";
my $formdata = CGI::Lite->new->parse_form_data();
my $tt = Template->new();
$tt->process( "ol.html", $formdata ) || die $tt->error();
