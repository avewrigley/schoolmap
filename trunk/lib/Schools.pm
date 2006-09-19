package Schools;

use strict;
use warnings;

use HTML::Entities qw( encode_entities );

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    require DBI;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{where} = 'dfes.name = ofsted.name AND dfes.postcode = ofsted.postcode AND ';
    if ( $self->{type} )
    {
        my @types = ref( $self->{type} ) eq 'ARRAY' ? @{$self->{type}} : ( $self->{type} );
        if ( @types )
        {
            $self->{where} = "(" . join( " OR ", map( "pupils_$_ <> 0", @types ) ) . ") AND ";
        }
    }
    my $ofstedType = $self->{ofstedType};
    if ( $ofstedType && $ofstedType ne 'all' )
    {
        warn "ofstedType: $ofstedType\n";
        $self->{where} .= "ofsted.type = '$ofstedType' AND ";
    }
    require Geo::Distance;
    $self->{geo} = Geo::Distance->new;
    $self->{geo}->formula( "cos" );
    return $self;
}

sub schools_count
{
    my $self = shift;
    my $sql = <<EOF;
SELECT count( * ) from dfes,ofsted WHERE 
$self->{where}
dfes.lon > $self->{minX} AND 
dfes.lon < $self->{maxX} AND 
dfes.lat > $self->{minY} AND
dfes.lat < $self->{maxY} 
EOF
    warn $sql;
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my ( $nschools ) = $sth->fetchrow_array;
    return $nschools;
}

sub types
{
    my $self = shift;
    my $sql = <<EOF;
SELECT DISTINCT type from dfes
EOF
    warn $sql;
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my @types;
    while ( my ( $type ) = $sth->fetchrow_array )
    {
        push( @types, $type );
    }
    return join( ",", @types );
}

sub school_name_xml
{
    my $self = shift;
    my $what = $self->what();
    my $sql = " SELECT $what FROM dfes WHERE name LIKE ?";
    $sql .= "  LIMIT $self->{limit}" if $self->{limit};
    warn $sql;
    my $sth = $self->{dbh}->prepare( $sql );
    my $nschools = $sth->execute( "%" . $self->{schoolname} . "%" );
    my $xml = "<data><schools nschools=\"$nschools\">";
    while ( my $school = $sth->fetchrow_hashref )
    {
        $self->add_distance( $school );
        $xml .= $self->school_xml( $school );
    }
    $xml .= "</schools></data>";
    warn $xml;
    return $xml;
}

sub add_distance
{
    my $self = shift;
    my $school = shift;
    return unless $self->{centreX} && $self->{centreY};
    $school->{distance} = sprintf( "%.2f", $self->{geo}->distance(
        'mile',
        $school->{lon}, $school->{lat} => $self->{centreX}, $self->{centreY},
    ) );
}

sub what
{
    my $self = shift;
    return 'dfes.*, ofsted.url AS ofsted_url, ofsted.type AS ofsted_type';
}

sub schools_xml
{
    my $self = shift;
    my $sth;
    if ( $self->{schoolname} )
    {
        return $self->school_name_xml;
    }
    my $nschools = $self->schools_count();
    warn "nschools: $nschools\n";
    my $xml = "<data><schools nschools=\"$nschools\">";
    my $what = $self->what();
    if ( $self->{orderBy} eq 'distance' )
    {
        my $sql = <<EOF;
SELECT 
    $what,
    acos( ( sin( ? ) * sin( dfes.lat ) ) + ( cos( ? ) * cos( dfes.lat ) * cos( dfes.lon - ? ) ) ) AS cos_dist
FROM dfes,ofsted WHERE
$self->{where}
dfes.lon > $self->{minX} AND 
dfes.lon < $self->{maxX} AND 
dfes.lat > $self->{minY} AND
dfes.lat < $self->{maxY}
ORDER BY cos_dist
EOF
        $sql .= " LIMIT $self->{limit}" if $self->{limit};
        warn "$self->{centreY}, $self->{centreY}, $self->{centreX}\n";
        warn $sql;
        $sth = $self->{dbh}->prepare( $sql );
        $sth->execute( 
            $self->{centreY},
            $self->{centreY},
            $self->{centreX}, 
        );
    }
    else
    {
        my $sql = <<EOF;
SELECT $what FROM dfes,ofsted WHERE
$self->{where}
dfes.lon > $self->{minX} AND
dfes.lon < $self->{maxX} AND
dfes.lat > $self->{minY} AND
dfes.lat < $self->{maxY}
ORDER BY $self->{orderBy} DESC
EOF
        $sql .= " LIMIT $self->{limit}" if $self->{limit};
        warn "$sql\n";
        $sth = $self->{dbh}->prepare( $sql );
        $sth->execute();
    }
    while ( my $school = $sth->fetchrow_hashref )
    {
        $self->add_distance( $school );
        $xml .= $self->school_xml( $school );
    }
    $xml .= "</schools></data>";
    return $xml;
}

sub school_xml
{
    my $self = shift;
    my $school = shift;
    return
        "<school" . join( "",
        map( 
            " $_=" .
            '"' .
            encode_entities( $school->{$_}, '<>&"' ) .
            '"', 
            keys %$school 
        ) ) .
        "/>"
    ;
}

1;
