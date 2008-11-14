#!/usr/bin/env perl

my $module = shift;
$module =~ s/::/\//g;
$module .= ".pm";
for ( @INC )
{
    print "$_/$module\n" if -e"$_/$module";
}

