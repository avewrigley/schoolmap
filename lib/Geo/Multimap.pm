package Geo::Multimap;

$VERSION = '1.00';

use strict;
use warnings;

use vars qw( $VERSION );

use Carp;
use DBI;
require HTML::TreeBuilder;
use LWP::Simple;

sub new
{
    my $class = shift;
    my $self = bless {}, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap' )
        or croak "Cannot connect: $DBI::errstr"
    ;
    $self->{ssth} = $self->{dbh}->prepare( "SELECT * FROM postcode WHERE code = ?" );
    $self->{isth} = $self->{dbh}->prepare( "INSERT INTO postcode (code, lat, lon ) VALUES ( ?, ?, ? )" );
    return $self;
}

sub DESTROY
{
    my $self = shift;
    return unless $self->{dbh};
    $self->{ssth}->finish() if $self->{ssth};
    $self->{isth}->finish() if $self->{isth};
    $self->{dbh}->disconnect();
}

sub get_text_nodes
{
    my $html = shift;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse( $html );
    my $node = $tree->elementify();
    my @tnodes;
    my @nodes = $node->look_down( @_ );
    for my $n ( @nodes )
    {
        () = $n->look_down(
            sub {
                my $element = shift;
                push( 
                    @tnodes, 
                    grep { ! ref( $_ ) && $_ =~ /\S/ } $element->content_list 
                );
            }
        );
    }
    $tree->destroy();
    return @tnodes;
}

my $multimap_url = "http://www.multimap.com/maps/?&hloc=GB|";

sub coords
{
    my $self = shift;
    my $postcode = shift;
    my %output = $self->find( $postcode );
    my ( $lat, $lon ) = @output{qw(lat lon)};
    croak "no lat / lon for $postcode" unless defined $lat && defined $lon;
    return ( $lat, $lon );
}

sub db_find
{
    my $self = shift;
    my $postcode = shift;
    $self->{ssth}->execute( $postcode );
    my $output = $self->{ssth}->fetchrow_hashref;
    if ( $output )
    {
        warn "found coords $output->{lat},$output->{lon} in db for $postcode\n";
        return $output;
    }
    warn "no entry in db for $postcode\n";
    return;
}

sub all
{
    my $self = shift;
    my $limit = shift;
    my $sql = "SELECT * FROM postcode";
    $sql .= " LIMIT $limit" if defined $limit;
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    return $sth->fetchall_arrayref( {} );
}

sub find
{
    my $self = shift;
    my $pc = shift;
    my $postcode = uc( $pc );
    $postcode =~ s/\s*//g;
    my $output = $self->db_find( $postcode );
    return %$output if $output;
    my $url = "$multimap_url$postcode";
    my $html = get( $url );
    open( FH, ">foo" );
    my ( $lat ) = $html =~ qr{<span class="latitude">([\-0-9\.]+)</span>}smi;
    warn "lat: $lat\n";
    my ( $lon ) = $html =~ qr{<span class="longitude">([\-0-9\.]+)</span>}smi;
    warn "lon: $lon\n";
    unless ( defined( $lat ) && defined( $lon ) )
    {
        warn "can't get coords for $postcode from $url\n";
        return;
    }
    warn "found coords $lat,$lon for $postcode from $url\n";
    $self->{isth}->execute( $postcode, $lat, $lon );
    return ( code => $postcode, lat => $lat, lon => $lon );
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


#------------------------------------------------------------------------------
#
# True ...
#
#------------------------------------------------------------------------------

1;

