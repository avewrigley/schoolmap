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

my $dbh;

{
    my ( %url, %description, %target );

    sub add_source
    {
        my $source = shift;
        my $sql = shift;
        warn "$sql\n";
        my $sth = $dbh->prepare( $sql );
        $sth->execute();
        my ( $url ) = $sth->fetchrow;
        return unless $url;
        warn "URL = $url\n";
        $url{$source->{name}} = $url;
        $description{$source->{name}} = $source->{description};
        $target{$source->{name}} = "school";
        $sth->finish();
    }

    sub get_sources { return keys %url; }
    sub get_url { return $url{$_[0]}; }

    sub get_tab
    {
        my $source = shift;
        my $class = shift;
        return <<EOF;
<li><a 
    $class 
    target="$target{$source}" 
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

open( STDERR, ">>../logs/school.log" );
warn "$$ at ", scalar( localtime ), "\n";
print "Content-Type: text/html\n\n";
my %formdata = CGI::Lite->new->parse_form_data();
warn map "$_ = $formdata{$_}\n", keys %formdata;
my $school_id = $formdata{school_id} or die "no school_id\n";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $sql = "SELECT * FROM school WHERE school.school_id = '$school_id'";
my $sth = $dbh->prepare( $sql );
$sth->execute();
my $school = $sth->fetchrow_hashref;
$sth->finish();
$sql = "SELECT * FROM source";
$sth = $dbh->prepare( $sql );
$sth->execute();
my %types = (
    post16 => "GCE and VCE",
    secondary => "GCSE",
    primary => "Key stage 2",
);

while ( my $source = $sth->fetchrow_hashref )
{
    if ( $source->{name} eq 'dfes' )
    {
        for my $type ( keys %types )
        {
            my $type_source = {
                name => "dfes_$type",
                description => "$source->{description} - $types{$type}",
            };
            add_source( 
                $type_source, 
                "SELECT $source->{name}.${type}_url FROM $source->{name} WHERE $source->{name}.school_id = '$school_id'" 
            );
        }
    }
    else
    {
        add_source( $source, "SELECT $source->{name}.$source->{name}_url FROM $source->{name} WHERE $source->{name}.school_id = '$school_id'" );
    }
}

$sth->finish();
$dbh->disconnect();
my @sources = get_sources();
my ( $iframe_source, $tabs );
if ( @sources )
{
    my $current_source = $sources[0];
    if ( $formdata{source} )
    {
        $current_source = $formdata{source};
        if ( $formdata{type} )
        {
            $current_source = "$formdata{source}_$formdata{type}";
        }
    }
    warn "current source: $current_source\n";
    $iframe_source = get_url( $current_source );
    $tabs = '';
    for my $source ( @sources )
    {
        my $class = '';
        if ( $current_source eq $source )
        {
            $class = 'class="current"';
        }
        $tabs .= get_tab( $source, $class );
    }
}

my $name = $school->{name}; 
$name =~ s/\s+/_/g;
$name =~ s/[^A-Za-z0-9_]//g;
my $links = 
    join " | ",
    map qq{<a href="$_->{url}">$_->{description}</a>},
    (
        { url => "/wiki/index.php/$name", description => "Schoolmap Wiki" },
        { url => "http://en.wikipedia.org/wiki/$name", description => "Wikipedia entry" },
    )
;
my $html = <<EOF;
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
        $links
        <div id="navcontainer"><ul id="navlist">$tabs</ul></div>
        <iframe style="border: 0" name="school" width="100%" height="100%" src="$iframe_source"></iframe>
        <script type="text/javascript">
            this.frame[0].top = this.frame[0];
        </script> 
    </body>
</html>
EOF

print $html;

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

