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
    my @what = ( 
        "dfes.*",
        "ofsted.*",
        "ofsted.url AS ofsted_url",
        "ofsted.type AS ofsted_type"
    );
    if ( $self->{orderBy} eq 'distance' )
    {
        push( 
            @what, 
            "acos( ( sin( ? ) * sin( ofsted.lat ) ) + ( cos( ? ) * cos( ofsted.lat ) * cos( ofsted.lon - ? ) ) ) AS cos_dist"
        );
    }
    $self->{what} = join( ",", @what );
    $self->{from} = "FROM ofsted LEFT JOIN dfes ON dfes.name = ofsted.name AND dfes.postcode = ofsted.postcode";
    my @where = ();
    if ( $self->{type} )
    {
        my @types = ref( $self->{type} ) eq 'ARRAY' ? @{$self->{type}} : ( $self->{type} );
        if ( @types )
        {
            push( 
                @where, 
                "(" . join( " OR ", map( "pupils_$_ <> 0", @types ) ) . ")" 
            );
        }
    }
    my $ofstedType = $self->{ofstedType};
    if ( $ofstedType && $ofstedType ne 'all' )
    {
        warn "ofstedType: $ofstedType\n";
        push( @where, "ofsted.type = '$ofstedType'" );
    }
    if ( $self->{minX} )
    {
        push( 
            @where,
            (
                "ofsted.lon > $self->{minX}",
                "ofsted.lon < $self->{maxX}",
                "ofsted.lat > $self->{minY}",
                "ofsted.lat < $self->{maxY}",
            )
        );
    }
    $self->{where} = @where ? "WHERE " . join( " AND ", @where ) : '';
    require Geo::Distance;
    $self->{geo} = Geo::Distance->new;
    $self->{geo}->formula( "cos" );
    return $self;
}

sub schools_count
{
    my $self = shift;
    my $sql = <<EOF;
SELECT count( * ) $self->{from} $self->{where}
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

sub schools_xml
{
    my $self = shift;
    my $sth;
    my $nschools = $self->schools_count();
    warn "nschools: $nschools\n";
    my $xml = "<data><schools nschools=\"$nschools\">";
    if ( $self->{orderBy} eq 'distance' )
    {
        my $sql = <<EOF;
SELECT $self->{what} $self->{from} $self->{where}
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
SELECT $self->{what} $self->{from} $self->{where}
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
        $xml .= $self->school_xml( $school ) . "\n";
    }
    $xml .= "</schools></data>";
    warn $xml;
    return $xml;
}

sub school_xml
{
    my $self = shift;
    my $school = shift;
    return
        "<school" . join( "",
        map( 
            "\n\t$_=" .
            '"' .
            encode_entities( $school->{$_}, '<>&"' ) .
            '"', 
            grep { length $school->{$_} } keys %$school 
        ) ) .
        "/>"
    ;
}

1;
