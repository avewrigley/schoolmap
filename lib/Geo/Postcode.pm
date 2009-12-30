package Geo::Postcode;

$VERSION = '1.00';

use strict;
use warnings;

use vars qw( $VERSION );

use DBI;

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap' )
        or die "Cannot connect: $DBI::errstr"
    ;
    return $self;
}

sub DESTROY
{
    my $self = shift;
    return unless $self->{dbh};
    $self->{dbh}->disconnect();
}

sub coords
{
    my $self = shift;
    my $postcode = shift;
    my %output = $self->find( $postcode );
    my ( $lon, $lat ) = @output{qw(lon lat)};
    # die "no lon / lat for $postcode" unless defined $lon && defined $lat;
    return $lon && $lat ? ( $lon, $lat ) : ();
}

sub find
{
    my $self = shift;
    my $pc = shift;
    my $postcode = uc( $pc );
    $postcode =~ s/\s*//g;
    my $sth = $self->{dbh}->prepare( "SELECT * FROM postcode WHERE code = ?" );
    $sth->execute( $postcode );
    my $output = $sth->fetchrow_hashref;
    $sth->finish();
    if ( $output )
    {
        warn "found coords $output->{lat},$output->{lon} in db for $postcode\n";
        return %{$output};
    }
    warn "no entry in db for $postcode\n";
    return;
}

sub add
{
    my $self = shift;
    my $pc = shift;
    my $lat = shift;
    my $lon = shift;

    my $postcode = uc( $pc );
    $postcode =~ s/\s*//g;
    my $sth = $self->{dbh}->prepare( "REPLACE INTO postcode ( code, lat, lon ) VALUES ( ?,?,? )" );
    $sth->execute( $postcode, $lat, $lon );
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

