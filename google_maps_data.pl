#!/usr/bin/env perl

use strict;
use warnings;

use Net::Google::AuthSub;
use Data::Dumper;
use YAML qw( LoadFile );
use LWP::UserAgent;
use XML::Simple;

my $config = LoadFile( "google.yaml" );
my $url = "http://maps.google.com/maps/feeds/maps/default/full";

my $auth = Net::Google::AuthSub->new(
    service => "local",
);
my $response = $auth->login( $config->{user}, $config->{pass} );
if ( $response->is_success ) 
{
    print "Hurrah! Logged in\n";
}
else {
    die "Login failed: ".$response->error."\n";
}

my %params = $auth->auth_params;
warn Dumper \%params;
my $ua = LWP::UserAgent->new();
$ua->default_headers->push_header( %params );
$response = $ua->get( $url );
unless ( $response->is_success )
{
    die $response->status_line;
}
my $xml = $response->content;
print $xml;
my $obj = XMLin( $xml );
my $links = $obj->{link};
my $post_url;
for my $link ( @$links )
{
    print Dumper $link;
    if ( $link->{rel} =~ /#post/ )
    {
        $post_url = $link->{href};
    }
}
print "$post_url\n";
