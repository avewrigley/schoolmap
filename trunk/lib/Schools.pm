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
        "school.*",
        "isi.*",
        "ofsted.url AS ofsted_url",
        "isi.url AS isi_url",
        "dfes.url AS dfes_url",
    );
    $self->{args} = [];
    if ( $self->{orderBy} && $self->{orderBy} eq 'distance' )
    {
        push( 
            @what, 
            "(((acos(sin((?*pi()/180)) * sin((school.lat*pi()/180)) + cos((?*pi()/180)) * cos((school.lat*pi()/180)) * cos(((? - school.lon)*pi()/180))))*180/pi())*60*1.1515) as geo_dist",
            # "acos( ( sin( ? ) * sin( school.lat ) ) + ( cos( ? ) * cos( school.lat ) * cos( school.lon - ? ) ) ) AS geo_dist"
        );
        $self->{args} = [
            $self->{centreY},
            $self->{centreY},
            $self->{centreX}, 
        ];
    }
    $self->{what} = join( ",", @what );
    my @where = ();
    if ( $self->{source} )
    {
        $self->{what} = "*";
        push( @where, "$self->{source}.school_id = school.school_id" );
        $self->{from} = "FROM school, $self->{source}";
    }
    else
    {
        $self->{from} = <<EOF;
FROM school 
    LEFT JOIN ofsted ON ofsted.school_id = school.school_id 
    LEFT JOIN dfes ON dfes.school_id = school.school_id
    LEFT JOIN isi ON isi.school_id = school.school_id
EOF
    }
    my $type = $self->{type};
    if ( $type && $type ne 'all' )
    {
        warn "type: $type\n";
        push( @where, "school.type = '$type'" );
    }
    if ( $self->{minX} )
    {
        push( 
            @where,
            (
                "school.lon > $self->{minX}",
                "school.lon < $self->{maxX}",
                "school.lat > $self->{minY}",
                "school.lat < $self->{maxY}",
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
    my $nschools = $self->schools_count();
    warn "nschools: $nschools\n";
    my $xml = "<data><schools nschools=\"$nschools\">";
    my $sql = "SELECT $self->{what} $self->{from} $self->{where}";
    if ( $self->{orderBy} )
    {
        if ( $self->{orderBy} eq 'distance' )
        {
            $sql .= " ORDER BY geo_dist";
        }
        else
        {
            $sql .= " ORDER BY $self->{orderBy} DESC";
        }
    }
    $sql .= " LIMIT $self->{limit}" if $self->{limit};
    warn "$sql\n";
    warn "ARGS: @{$self->{args}}\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @{$self->{args}} );
    while ( my $school = $sth->fetchrow_hashref )
    {
        $self->add_distance( $school );
        $xml .= $self->school_xml( $school ) . "\n";
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
            "\n\t$_=" .
            '"' .
            encode_entities( $school->{$_}, '<>&"' ) .
            '"', 
            grep { defined $school->{$_} && length $school->{$_} } keys %$school 
        ) ) .
        "/>"
    ;
}

1;
