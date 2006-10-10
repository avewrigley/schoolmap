package Schools;

use strict;
use warnings;

use Carp;
use HTML::Entities qw( encode_entities );
use Template;

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    require DBI;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    my @what = ( "*,school.*" );
    $self->{args} = [];
    if ( $self->{centreX} && $self->{centreY} )
    {
        push( 
            @what, 
            "(((acos(sin((?*pi()/180)) * sin((school.lat*pi()/180)) + cos((?*pi()/180)) * cos((school.lat*pi()/180)) * cos(((? - school.lon)*pi()/180))))*180/pi())*60*1.1515) as distance",
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
FROM school,school_type
    LEFT JOIN ofsted ON ofsted.school_id = school.school_id 
    LEFT JOIN dfes ON dfes.school_id = school.school_id
    LEFT JOIN isi ON isi.school_id = school.school_id
EOF
    $self->{what} = join( ",", @what );
    my $type = $self->{type};
    push( @where, "school_type.school_id = school.school_id" );
    if ( $type && $type ne 'all' )
    {
        warn "type: $type\n";
        push( @where, "school_type.type = '$type'" );
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
    my $sql = "SELECT DISTINCT type from school_type";
    if ( $self->{source} && $self->{source} ne 'all' )
    {
        $sql = <<EOF;
SELECT DISTINCT type 
    FROM school_type,$self->{source} 
    WHERE $self->{source}.school_id = school_type.school_id
EOF
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

sub sources_xml
{
    my $self = shift;
    my $sql = "SELECT * from source";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $sources = $sth->fetchall_arrayref( {} );
    $sth->finish();
    my $tt = Template->new( { INCLUDE_PATH => "../templates" } );
    my $xml;
    $tt->process( "source.xml", { sources => $sources }, \$xml ) 
        || croak $tt->error
    ;
    warn $xml;
    return $xml;
}

sub keystages_xml
{
    my $self = shift;
    my $sql = "SELECT * from keystage";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $keystages = $sth->fetchall_arrayref( {} );
    $sth->finish();
    my $tt = Template->new( { INCLUDE_PATH => "../templates" } );
    my $xml;
    $tt->process( "keystage.xml", { keystages => $keystages }, \$xml ) 
        || croak $tt->error
    ;
    warn $xml;
    return $xml;
}

sub schools_xml
{
    my $self = shift;
    my $sql = "SELECT $self->{what} $self->{from} $self->{select_where}";
    if ( $self->{order_by} )
    {
        if ( $self->{order_by} eq 'distance' )
        {
            $sql .= " ORDER BY distance";
        }
        else
        {
            $sql .= " ORDER BY average_$self->{order_by} DESC";
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
    my @schools;
    my $types_sth = $self->{dbh}->prepare( "SELECT type FROM school_type WHERE school_id = ?" );
    while ( my $school = $sth->fetchrow_hashref )
    {
        $types_sth->execute( $school->{school_id} );
        $school->{type} = join " / ", map $_->[0], @{$types_sth->fetchall_arrayref()};
        warn "type for $school->{school_id} = $school->{type}\n";
        push( @schools, $school );
    }
    my $tt = Template->new( { INCLUDE_PATH => "../templates" } );
    my $xml;
    $tt->process(
        "school.xml",
        {
            schools => \@schools,
            nschools => $nschools
        },
        \$xml
    ) || croak $tt->error;
    return $xml;
}

1;
