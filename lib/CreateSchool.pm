package CreateSchool;

use strict;
use warnings;

require Geo::Postcode;
require Geo::Coder::Google;
use Data::Dumper;

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
    warn "lookup $school{$id_key} ...\n";
    $self->{ssth}->execute( @school{qw(postcode name)} );
    my $school = $self->{ssth}->fetchrow_hashref();
    if ( $school )
    {
        warn "UPDATE $school->{name}\n";
        my $school = $self->{usth}->execute( @school{$id_key, qw(postcode name)} );
        return;
    }
    warn "can't find school for $school{name}\n";
    warn "school: $school{$id_key}\n";
    $school{postcode} = uc( $school{postcode} );
    $school{postcode} =~ s/[^0-9A-Z]//g;
    if ( $school{lat} && $school{lon} )
    {
        $self->{geopostcode}->add( $school{postcode}, $school{lat}, $school{lon} );
    }
    else
    {
        %school = ( %school, $self->{geopostcode}->find( $school{postcode} ) );
        if ( ! $school{lat} && $school{lon} )
        {
            warn "looking up $postcode on google ...\n";
            my $location = $self->{geogoogle}->geocode( location => $postcode );
            warn Dumper $location;
            exit;
        }
    }
    die "no lat / lon for postcode $school{postcode}" 
        unless $school{lat} && $school{lon};
    $self->{isth} = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( $id_key, name, postcode, address ) VALUES ( ?,?,?,? )
SQL
    $self->{isth}->execute( @school{$id_key, qw( name postcode address )} );
    $self->{isth}->finish();
}

my $api_key = "ABQIAAAAzvdwQCWLlw5TXpo7sNhCSRTpDCCGWHns9m2oc9sQQ_LCUHXVlhS7v4YbLZCNgHXnaepLqcd-J0BBDw";
sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    die "no dbh\n" unless $self->{dbh};
    $self->{geopostcode} = Geo::Postcode->new( backoff => $args{backoff_postcodes} );
    $self->{geogoogle} = Geo::Coder::Google->new(
        apikey => $api_key,
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
