#!/usr/bin/env perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use CGI::Lite;
require DBI;

open( STDERR, ">>../logs/school.log" );
warn "$$ at ", scalar( localtime ), "\n";
print "Content-Type: text/html\n\n";
my %formdata = CGI::Lite->new->parse_form_data();
my $school_id = $formdata{school_id} or die "no school_id\n";
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my ( %url, %description );
my $sql = "SELECT * FROM school WHERE school.school_id = '$school_id'";
my $sth = $dbh->prepare( $sql );
$sth->execute();
my $school = $sth->fetchrow_hashref;
$sth->finish();
$sql = "SELECT * FROM source";
$sth = $dbh->prepare( $sql );
$sth->execute();
while ( my $source = $sth->fetchrow_hashref )
{
    my $sql = "SELECT $source->{name}.$source->{name}_url FROM $source->{name} WHERE $source->{name}.school_id = '$school_id'";
    warn "$sql\n";
    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    my ( $url ) = $sth->fetchrow;
    next unless $url;
    warn "URL = $url\n";
    $url{$source->{name}} = $url;
    $description{$source->{name}} = $source->{description};
    $sth->finish();
}
$sth->finish();
$dbh->disconnect();
my @sources = keys %url;
my ( $iframe_source, $links );
if ( @sources )
{
    my $current_source = $formdata{source} || $sources[0];
    $iframe_source = $url{$current_source};
    $links = '';
    for my $source ( @sources )
    {
        my $class = '';
        if ( $current_source eq $source )
        {
            $class = 'class="current"';
        }
        $links .= <<EOF;
<li><a 
    $class 
    target="school" 
    href="$url{$source}"
    onclick="
        try {
            var current = YAHOO.util.Dom.getElementsByClassName( 'current' );
            current[0].className = '';
            this.className = 'current';
        }
        catch( e ) { alert( e ) }
        return true;
    "
>$description{$source}</a></li>
EOF
    }
}

print <<EOF;
<html>
    <head>
        <title>$school->{name}</title>
        <script type="text/javascript" src="/js/yui/build/yahoo/yahoo.js"></script>
        <script type="text/javascript" src="/js/yui/build/dom/dom.js"></script> 
        <link type="text/css" rel="stylesheet" href="/css/navbar.css" /> 
    </head>
    <body>
        <h2>$school->{name}</h2>
        <p>$school->{address}</p>
        <p>$school->{postcode}</p>
        <div id="navcontainer"><ul id="navlist">$links</ul></div>
        <iframe style="border: 0" name="school" width="100%" height="100%" src="$iframe_source"></iframe>
    </body>
</html>
EOF

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

