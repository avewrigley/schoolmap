package CreateSchool;

use strict;
use warnings;

require Geo::Postcode;
require Geo::Coder::Google;
require Geo::Coder::Yahoo;
use Data::Dumper;

sub get_location
{
    my $self = shift;
    my $address = shift;
    my %opts = @_;

    die "no using parameter\n" unless my $using = $opts{using};
    warn "looking up $address using $using ...\n";
    if ( $using eq 'google' )
    {
        my $response = $self->{geogoogle}->geocode( location => $address );
        if ( $response->{Status}{code} == 620 )
        {
            die "Too many geocoding queries\n";
        }
        if ( $response->{Status}{code} != 200 )
        {
            die "geocoding query failed: $response->{Status}{code}\n";
        }
        my $location = $response->{Placemark}[0];
        die "failed to get location for $address\n" unless $location;
        my $coords = $location->{Point}{coordinates};
        return @$coords;
    }
    elsif ( $using eq 'yahoo' )
    {
        my $response = $self->{geoyahoo}->geocode( location => $address );
        my $location = $response->[0];
        die "failed to get location for $address:\n", Dumper( $response ), "\n" unless $location;
        warn "found $location->{longitude}, $location->{latitude}\n";
        return ( $location->{longitude}, $location->{latitude} );
    }
    else
    {
        die "don't know how to lookup using $using\n";
    }
}

sub create_school
{
    my $self = shift;
    my $id_key = shift;
    die "no id_key" unless $id_key;
    my %school = @_;

    die "no name" unless $school{name};
    die "no postcode" unless $school{postcode};
    my $postcode = $school{postcode};
    die "no $id_key" unless $school{$id_key};
    $school{postcode} = uc( $school{postcode} );
    $school{postcode} =~ s/[^0-9A-Z]//g;
    # warn "lookup @school{qw(postcode name)} ...\n";
    $self->{ssth}->execute( @school{qw(postcode name)} );
    my $school = $self->{ssth}->fetchrow_hashref();
    if ( $school )
    {
        # warn "UPDATE $school->{name}\n";
        my $school = $self->{usth}->execute( @school{$id_key, qw(postcode name)} );
        return;
    }
    warn "new school: $school{name}\n";
    unless ( $school{lat} && $school{lon} )
    {
        ( $school{lon}, $school{lat} ) = $self->get_location( $school{address}, using => "yahoo" );
        die "no lat / lon for postcode $school{postcode}" 
            unless $school{lat} && $school{lon}
        ;
    }
    $self->{geopostcode}->add( $school{postcode}, $school{lat}, $school{lon} );
    $self->{isth} = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( $id_key, name, postcode, address ) VALUES ( ?,?,?,? )
SQL
    $self->{isth}->execute( @school{$id_key, qw( name postcode address )} );
    $self->{isth}->finish();
}

my $google_api_key = "ABQIAAAAzvdwQCWLlw5TXpo7sNhCSRTpDCCGWHns9m2oc9sQQ_LCUHXVlhS7v4YbLZCNgHXnaepLqcd-J0BBDw";
my $yahoo_api_key = "8iy5OSrV34EfmQoZVXSrpkinxPQT7jYcNPs8AbkK8ngkpqNt8.HJg4N.8dzzrcp6wdg-";
sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    die "no dbh\n" unless $self->{dbh};
    $self->{geopostcode} = Geo::Postcode->new( backoff => $args{backoff_postcodes} );
    $self->{geoyahoo} = Geo::Coder::Yahoo->new( appid => $yahoo_api_key );
    $self->{geogoogle} = Geo::Coder::Google->new(
        apikey => $google_api_key,
        host => "maps.google.co.uk",
    );
    $self->{ssth} = $self->{dbh}->prepare( "SELECT * FROM school WHERE postcode = ? AND name = ?" );
    $self->{usth} = $self->{dbh}->prepare( "UPDATE school SET ofsted_id = ? WHERE postcode = ? AND name = ?" );
    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self->{ssth}->finish if $self->{ssth};
    $self->{usth}->finish if $self->{ssth};
}

1;
