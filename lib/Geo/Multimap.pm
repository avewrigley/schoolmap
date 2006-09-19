package Geo::Multimap;

$VERSION = '1.00';

use strict;
use warnings;

use vars qw( $VERSION );

use DBI;
require HTML::TreeBuilder;
use LWP::Simple;

sub new
{
    my $class = shift;
    my $self = bless {}, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap' )
        or die "Cannot connect: " . $DBI::errstr
    ;
    $self->{ssth} = $self->{dbh}->prepare( "SELECT * FROM postcode WHERE code = ?" );
    $self->{isth} = $self->{dbh}->prepare( "INSERT INTO postcode (code, lat, lon) VALUES ( ?, ?, ? )" );
    return $self;
}

sub get_text_nodes
{
    my $url = shift;
    my $html = get( $url );
    unless ( $html ) { warn "get $url failed"; return (); }
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

my $multimap_url = "http://www.multimap.com/map/browse.cgi?client=public&search_result=&db=pc&cidr_client=none&lang=&pc=";

sub coords
{
    my $self = shift;
    my %output = $self->find( @_ );
    my ( $lat, $lon ) = @output{qw(lat lon)};
    die "no lat / lon\n" unless defined $lat && defined $lon;
    return ( $lat, $lon );
}

sub db_find
{
    my $self = shift;
    my $postcode = shift;
    warn "db lookup $postcode\n";
    $self->{ssth}->execute( $postcode );
    my $output = $self->{ssth}->fetchrow_hashref;
    if ( $output )
    {
        warn map "$_ = $output->{$_}\n", keys %$output;
        return $output;
    }
    warn "$postcode not found in db\n";
    return;
}

sub find
{
    my $self = shift;
    my $pc = shift;
    my $postcode = uc( $pc );
    $postcode =~ s/\s*//g;
    my $output = $self->db_find( $postcode );
    return %$output if $output;
    my $mmu = "$multimap_url$postcode";
    warn "$mmu\n";
    my ( $lat, $lon );
    for ( get_text_nodes( $mmu, _tag => 'dd' ) )
    {
        if ( /\d{1,2}:\d{1,2}:\d{1,2}[NS] \((-?[0-9.]+)\)/ )
        {
            $lat = $1;
            warn "lat: $lat\n";
        }
        elsif ( /\d{1,2}:\d{1,2}:\d{1,2}[EW] \((\-?[0-9.]+)\)/ )
        {
            $lon = $1;
            warn "lon: $lon\n";
        }
        last if $lat && $lon;
    }
    return unless $lat && $lon;
    warn "insert $postcode, $lat, $lon\n";
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

