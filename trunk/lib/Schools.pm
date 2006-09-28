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
    my @what = ( "*" );
    $self->{args} = [];
    if ( $self->{order_by} && $self->{order_by} eq 'distance' )
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
    my @where = ();
    if ( $self->{source} && $self->{source} ne 'all' )
    {
        push( @where, "$self->{source}.school_id = school.school_id" );
        $self->{from} = "FROM school, $self->{source}";
    }
    $self->{from} = <<EOF;
FROM school 
    LEFT JOIN ofsted ON ofsted.school_id = school.school_id 
    LEFT JOIN dfes ON dfes.school_id = school.school_id
    LEFT JOIN isi ON isi.school_id = school.school_id
EOF
    $self->{what} = join( ",", @what );
    my $type = $self->{type};
    if ( $type && $type ne 'all' )
    {
        warn "type: $type\n";
        push( @where, "school.type = '$type'" );
    }
    my ( @select_where, @count_where );
    @select_where = @count_where = @where;
    if ( $self->{minX} && $self->{maxX} && $self->{minY} && $self->{maxY} )
    {
        if ( $self->{order_by} ne 'distance' )
        {
            push( 
                @select_where,
                (
                    "school.lon > $self->{minX}",
                    "school.lon < $self->{maxX}",
                    "school.lat > $self->{minY}",
                    "school.lat < $self->{maxY}",
                )
            );
        }
        push( 
            @count_where,
            (
                "school.lon > $self->{minX}",
                "school.lon < $self->{maxX}",
                "school.lat > $self->{minY}",
                "school.lat < $self->{maxY}",
            )
        );
    }
    $self->{select_where} = @select_where ? "WHERE " . join( " AND ", @select_where ) : '';
    $self->{count_where} = @count_where ? "WHERE " . join( " AND ", @count_where ) : '';
    require Geo::Distance;
    $self->{geo} = Geo::Distance->new;
    $self->{geo}->formula( "cos" );
    return $self;
}

sub count
{
    my $self = shift;
    my $sql = <<EOF;
SELECT count( * ) $self->{from} $self->{count_where}
EOF
    warn $sql;
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my ( $nschools ) = $sth->fetchrow_array;
    return $nschools;
}

my %label = (
    secondary => "Secondary",
    post16 => "Sixteen Plus",
    primary => "Primary",
    independent => "Independent",
    nursery => "Nursery",
    sen => "Special School",
    pru => "Pupil Referral Unit",
);

sub types_xml
{
    my $self = shift;
    my $sql = "SELECT DISTINCT type from school";
    if ( $self->{source} && $self->{source} ne 'all' )
    {
        $sql = "SELECT DISTINCT type from school,$self->{source} WHERE $self->{source}.school_id = school.school_id";
    }
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $xml = "<types>";
    while ( my ( $type ) = $sth->fetchrow_array )
    {
        $xml .= 
            '<type name="' . 
            encode_entities( $type, '<>&"' )  .
            '" label="' .
            encode_entities( $label{$type}, '<>&"' )  .
            '"/>'
        ;
    }
    $sth->finish();
    $xml .= "</types>";
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

sub schools_xml
{
    my $self = shift;
    my $sql = "SELECT $self->{what} $self->{from} $self->{select_where}";
    if ( $self->{order_by} )
    {
        if ( $self->{order_by} eq 'distance' )
        {
            $sql .= " ORDER BY geo_dist";
        }
        else
        {
            $sql .= " ORDER BY $self->{order_by} DESC";
        }
    }
    $sql .= " LIMIT $self->{limit}" if $self->{limit};
    warn "$sql\n";
    warn "ARGS: @{$self->{args}}\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @{$self->{args}} );
    my $nrows = $sth->rows;
    my $nschools = $self->count();
    $nschools = $nrows if $nrows > $nschools;
    warn "nschools: $nschools\n";
    my $xml = "<data><schools nschools=\"$nschools\">";
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
            grep { defined $school->{$_} && length $school->{$_} } keys %$school 
        ) ) .
        "/>"
    ;
}

1;
