#!/usr/bin/env perl

use warnings;
use strict;

my $module = shift;
$module =~ s/::/\//g;
$module .= ".pm";
for ( @INC )
{
    print "$_/$module\n" if -e"$_/$module";
}

