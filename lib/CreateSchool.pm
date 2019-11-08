package CreateSchool;

use strict;
use warnings;

require Geo::Postcode;
require Geo::Coder::OpenCage;
use File::Slurp;
use YAML qw( LoadFile );
use Data::Dumper;
use FindBin qw( $Bin );

sub get_location
{
    my $self = shift;
    my $school = shift;
    my %opts = @_;

    if ( $school->{lat} && $school->{lon} )
    {
        return( $school->{lat}, $school->{lon} );
    }
    my @coords = $self->{geopostcode}->coords( $school->{postcode} );
    return @coords if @coords == 2 && $coords[0] && $coords[1];
    my $response = $self->{geocoder}->geocode( location => $school->{postcode} );
    my @results = @{$response->{results}};
    my $location = $results[0]{geometry};
    if ( $location )
    {
        $self->{geopostcode}->add( $school->{postcode}, $location->{lat}, $location->{lng} );
        warn "$location->{lat}, $location->{lng}";
        return ( $location->{lat}, $location->{lng} );
    }
    else
    {
        warn "failed to get location for $school->{postcode}\n";
    }
    die "no lat / lon\n";
}

sub get_school
{
    my $self = shift;
    my $ofsted_id = shift;
    my $sth = $self->{dbh}->prepare( <<SQL );
SELECT * FROM school WHERE ofsted_id = ?
SQL
    $sth->execute( $ofsted_id );
    my $school = $sth->fetchrow_hashref;
    return $school;
}

sub create_school
{
    my $self = shift;
    my %school = @_;

    die "no ofsted_id" unless $school{ofsted_id};
    die "no name" unless $school{name};
    die "no postcode" unless $school{postcode};
    my $postcode = $school{postcode};
    $school{postcode} = uc( $school{postcode} );
    $school{postcode} =~ s/[^0-9 A-Z]//g;
    warn "new school: $school{name}\n";
    ( $school{lat}, $school{lon} ) = $self->get_location( \%school );
    my $isth = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( ofsted_id, ofsted_url, name, type, phase, postcode, address, lat, lon ) VALUES ( ?,?,?,?,?,?,?,?,? )
SQL
    $isth->execute( @school{qw( ofsted_id url name type phase postcode address lat lon )} );
}

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    die "no dbh\n" unless $self->{dbh};
    my $config = LoadFile( "$Bin/config/schoolmap.yaml" );
    $self->{geopostcode} = Geo::Postcode->new( );
    $self->{geocoder} = Geo::Coder::OpenCage->new( api_key => $config->{open_cage_api_key} );
    return $self;
}

1;
