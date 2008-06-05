package School;

use strict;
use warnings;

use Carp;
use CGI::Lite;
require DBI;
use Template;
use Data::Dumper;

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{types} = {
        post16 => "GCE and VCE",
        secondary => "GCSE",
        primary => "Key stage 2",
    };
    warn Dumper $self;
    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self->{dbh}->disconnect();
}

sub get_tabs
{
    my $self = shift;
    my $school = shift;
    my $type = shift;
    my $tabs = [
        { 
            url => "http://en.wikipedia.org/wiki/$school->{name}", 
            description => "Wikipedia entry" 
        },
    ];
    for my $url_type ( "ofsted", keys %{$self->{types}} )
    {
        my $key = "${url_type}_url";
        warn "$url_type ($type - $key) TAB\n";
        if ( my $url = $school->{$key} )
        {
            warn "ADD A $url_type TAB\n";
            push( @$tabs, {
                    url => $url,
                    description => $self->{types}{$url_type} || "Ofsted",
                    current => $url_type eq $type
                }
            );
        }
    }
    return $tabs;
}

sub html
{
    my $self = shift;

    my $school_sql = "SELECT * FROM school LEFT JOIN dfes USING ( dfes_id ) LEFT JOIN ofsted USING( ofsted_id ) WHERE school.$self->{table}_id = ?";
    warn "$school_sql\n";
    my $school_sth = $self->{dbh}->prepare( $school_sql );
    $school_sth->execute( $self->{id} );
    my $school = $school_sth->fetchrow_hashref;
    $school_sth->finish();
    warn Dumper $school;
    $school->{name} =~ s/\s+/_/g;
    $school->{name} =~ s/[^A-Za-z0-9_]//g;
    my $key = $self->{type} ? "$self->{type}_url" : "$self->{table}_url";
    my $iframe_source = $school->{$key};
    warn "iframe_source: $key $iframe_source\n";
    my $tabs = $self->get_tabs( $school, $self->{type} || $self->{table} );
    my $tt = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    $tt->process(
        "school.html", 
        { 
            school => $school,
            tabs => $tabs,
            iframe_source => $iframe_source,
        }
    );
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

