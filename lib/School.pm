package School;

use strict;
use warnings;

use Carp;
use CGI::Lite;
require DBI;
use Template;

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{sources} = [];
    $self->{url} = {};
    $self->{description} = {};
    $self->{target} = {};
    $self->{types} = {
        post16 => "GCE and VCE",
        secondary => "GCSE",
        primary => "Key stage 2",
    };
    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self->{dbh}->disconnect();
}

sub add_source
{
    my $self = shift;
    my $source = shift;
    my $sql = shift;
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my ( $url ) = $sth->fetchrow;
    return unless $url;
    $self->{url}{$source->{name}} = $url;
    $self->{description}{$source->{name}} = $source->{description};
    $self->{target}{$source->{name}} = "school";
    push( @{$self->{sources}}, $source->{name} );
    $sth->finish();
}

sub get_tab
{
    my $self = shift;
    my $source = shift;
    my $class = shift;
    warn "get tab for $source\n";
    return {
        target => $self->{target}{$source},
        url => $self->{url}{$source},
        description => $self->{description}{$source},
        class => $class,
    };
}

sub html
{
    my $self = shift;

    my $school_id = $self->{school_id} or die "no school_id\n";
    my $school_sql = "SELECT * FROM school WHERE school.school_id = ?";
    my $school_sth = $self->{dbh}->prepare( $school_sql );
    $school_sth->execute( $school_id );
    my $school = $school_sth->fetchrow_hashref;
    $school_sth->finish();
    my $source_sql = "SELECT * FROM source WHERE name <> 'dfes'";
    my $source_sth = $self->{dbh}->prepare( $source_sql );
    $source_sth->execute();
    while ( my $source = $source_sth->fetchrow_hashref )
    {
        $self->add_source( $source, "SELECT $source->{name}.$source->{name}_url FROM $source->{name} WHERE $source->{name}.school_id = '$school_id'" );
    }

    for my $type ( keys %{$self->{types}} )
    {
        my $year_sql = "SELECT DISTINCT year FROM dfes WHERE dfes.school_id = ? AND ${type}_url IS NOT NULL";
        my $year_sth = $self->{dbh}->prepare( $year_sql );
        $year_sth->execute( $school_id );
        my @years = map { $_->[0] } @{$year_sth->fetchall_arrayref()};
        $year_sth->finish();
        for my $year ( @years )
        {
            my $type_source = {
                name => "dfes_${year}_$type",
                description => "$self->{types}{$type} ($year)",
            };
            $self->add_source( 
                $type_source, 
                "SELECT ${type}_url FROM dfes WHERE dfes.school_id = '$school_id' AND year = '$year'" 
            );
        }
    }

    $source_sth->finish();
    my ( $iframe_source );
    my @tabs;
    if ( @{$self->{sources}} )
    {
        my $current_source = $self->{sources}[0];
        if ( $self->{source} )
        {
            $current_source = $self->{source};
            if ( $self->{type} )
            {
                $current_source = "$self->{source}_$self->{type}";
                if ( $self->{year} )
                {
                    $current_source = "$self->{source}_$self->{year}_$self->{type}";
                }
            }
        }
        $iframe_source = $self->{url}{$current_source};
        for my $source ( @{$self->{sources}} )
        {
            push( @tabs, $self->get_tab( $source, $current_source eq $source ) );
        }
    }

    my $name = $school->{name}; 
    $name =~ s/\s+/_/g;
    $name =~ s/[^A-Za-z0-9_]//g;
    my $tt = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
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

