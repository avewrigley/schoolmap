package CreateSchool;

use strict;
use warnings;

require Geo::Multimap;

sub create_school
{
    my $self = shift;
    my $id_key = shift;
    die "no id_key" unless $id_key;
    my %school = @_;

    die "no name" unless $school{name};
    die "no postcode" unless $school{postcode};
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
    unless ( $school{lat} && $school{lon} )
    {
        ( $school{lat}, $school{lon} ) = $self->{geo}->coords( $school{postcode} );
    }
    die "no lat / lon for postcode $school{postcode}" 
        unless $school{lat} && $school{lon};
    $self->{isth} = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( $id_key, name, postcode, address ) VALUES ( ?,?,?,? )
SQL
    $self->{isth}->execute( @school{$id_key, qw( name postcode address )} );
    $self->{isth}->finish();
}

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    die "no dbh\n" unless $self->{dbh};
    $self->{geo} = Geo::Multimap->new();
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
