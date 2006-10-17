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
use Template;

my $dbh;

{
    my ( @sources, %url, %description, %target );

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
        push( @sources, $source->{name} );
        $sth->finish();
    }

    sub get_sources { return @sources }
    sub get_url { return $url{$_[0]}; }

    sub get_tab
    {
        my $source = shift;
        my $class = shift;
        {
            target => $target{$source},
            url => $url{$source},
            description => $description{$source},
            class => $class,
        }
    }
}

open( STDERR, ">>../logs/school.log" );
warn "$$ at ", scalar( localtime ), "\n";
print "Content-Type: text/html\n\n";
my %formdata = CGI::Lite->new->parse_form_data();
warn map "$_ = $formdata{$_}\n", keys %formdata;
my $school_id = $formdata{school_id} or die "no school_id\n";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $school_sql = "SELECT * FROM school WHERE school.school_id = ?";
my $school_sth = $dbh->prepare( $school_sql );
$school_sth->execute( $school_id );
my $school = $school_sth->fetchrow_hashref;
$school_sth->finish();
my $source_sql = "SELECT * FROM source WHERE name <> 'dfes'";
my $source_sth = $dbh->prepare( $source_sql );
$source_sth->execute();
my %types = (
    post16 => "GCE and VCE",
    secondary => "GCSE",
    primary => "Key stage 2",
);

while ( my $source = $source_sth->fetchrow_hashref )
{
    add_source( $source, "SELECT $source->{name}.$source->{name}_url FROM $source->{name} WHERE $source->{name}.school_id = '$school_id'" );
}

for my $type ( keys %types )
{
    my $year_sql = "SELECT DISTINCT year FROM dfes WHERE dfes.school_id = ? AND ${type}_url IS NOT NULL";
    my $year_sth = $dbh->prepare( $year_sql );
    $year_sth->execute( $school_id );
    my @years = map { $_->[0] } @{$year_sth->fetchall_arrayref()};
    $year_sth->finish();
    warn "years: @years\n";
    for my $year ( @years )
    {
        my $type_source = {
            name => "dfes_${year}_$type",
            description => "$types{$type} ($year)",
        };
        add_source( 
            $type_source, 
            "SELECT ${type}_url FROM dfes WHERE dfes.school_id = '$school_id' AND year = '$year'" 
        );
    }
}

$source_sth->finish();
$dbh->disconnect();
my @sources = get_sources();
my ( $iframe_source );
my @tabs;
if ( @sources )
{
    my $current_source = $sources[0];
    if ( $formdata{source} )
    {
        $current_source = $formdata{source};
        if ( $formdata{type} )
        {
            $current_source = "$formdata{source}_$formdata{type}";
            if ( $formdata{year} )
            {
                $current_source = "$formdata{source}_$formdata{year}_$formdata{type}";
            }
        }
    }
    warn "current source: $current_source\n";
    $iframe_source = get_url( $current_source );
    for my $source ( @sources )
    {
        push( @tabs, get_tab( $source, $current_source eq $source ) );
    }
}

my $name = $school->{name}; 
$name =~ s/\s+/_/g;
$name =~ s/[^A-Za-z0-9_]//g;
my $tt = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
warn "iframe_source => $iframe_source\n";
$tt->process(
    "school.html", 
    { 
        school => $school,
        links => [
            { url => "/wiki/index.php/$name", description => "Schoolmap Wiki" },
            { url => "http://en.wikipedia.org/wiki/$name", description => "Wikipedia entry" },
        ],
        tabs => \@tabs,
        iframe_source => $iframe_source,
    }
);

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

