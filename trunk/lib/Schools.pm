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
    # $self->{debug} = 1;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    unless ( $self->{year} )
    {
        my $years = $self->years();
        $self->{year} = $years->[0]->{year};

    }
    warn "year: $self->{year}\n";
    my @where = ( "year = $self->{year}", "school.postcode = postcode.code" );
    my @what = ( "*" );
    my @args = ();
    my @from = ( "school", "postcode" );
    if ( $self->{centreX} && $self->{centreY} )
    {
        push( 
            @what, 
            "GLength(LineStringFromWKB(LineString(AsBinary(GeomFromText(?)), AsBinary(postcode.location)))) AS distance",
            # "acos( ( sin( ? ) * sin( school.lat ) ) + ( cos( ? ) * cos( school.lat ) * cos( school.lon - ? ) ) ) AS geo_dist"
        );
        push( @args, "POINT( $self->{centreX} $self->{centreY} )" );
    }
    if ( $self->{source} && $self->{source} ne 'all' )
    {
        push( @where, "$self->{source}.school_id = school.school_id" );
        push( @from, $self->{source} );
    }
    $self->{args} = \@args;
    $self->{what} = join( ",", @what );
    my $type = $self->{type};
    if ( $type && $type ne 'all' )
    {
        warn "type: $type\n";
        push( 
            @where, 
            "school_type.type = '$type'", 
            "school_type.school_id = school.school_id"
        );
        push( @from, "school_type" );
    }
    $self->{join} = join( "", map " LEFT JOIN $_ ON $_.school_id = school.school_id", qw( ofsted dfes isi ) );
    $self->{from} = "FROM " . join( ",", @from );
    my ( @select_where, @count_where );
    @select_where = @count_where = @where;
    if ( $self->{minX} && $self->{maxX} && $self->{minY} && $self->{maxY} )
    {
        if ( $self->{order_by} ne 'distance' )
        {
            push( 
                @select_where,
                (
                    "postcode.lon > $self->{minX}",
                    "postcode.lon < $self->{maxX}",
                    "postcode.lat > $self->{minY}",
                    "postcode.lat < $self->{maxY}",
                )
            );
        }
        push( 
            @count_where,
            (
                "postcode.lon > $self->{minX}",
                "postcode.lon < $self->{maxX}",
                "postcode.lat > $self->{minY}",
                "postcode.lat < $self->{maxY}",
            )
        );
    }
    $self->{select_where} = @select_where ? "WHERE " . join( " AND ", @select_where ) : '';
    $self->{count_where} = @count_where ? "WHERE " . join( " AND ", @count_where ) : '';
    $self->{tt} = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    return $self;
}

sub xml
{
    my $self = shift;
    if ( exists $self->{sources} )
    {
        $self->sources_xml();
    }
    elsif ( exists $self->{years} )
    {
        $self->years_xml();
    }
    elsif ( exists $self->{types} )
    {
        $self->types_xml();
    }
    elsif ( exists $self->{keystages} )
    {
        $self->keystages_xml();
    }
    else
    {
        $self->schools_xml();
    }
}

sub count
{
    my $self = shift;
    my $sql = <<EOF;
SELECT count( * ) $self->{from} $self->{join} $self->{count_where}
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
    print "<types>";
    while ( my ( $type ) = $sth->fetchrow_array )
    {
        print
            '<type name="' . 
            encode_entities( $type, '<>&"' )  .
            '" label="' .
            encode_entities( $label{$type}, '<>&"' )  .
            '"/>'
        ;
    }
    $sth->finish();
    print "</types>";
}

sub years
{
    my $self = shift;
    my $sql = "SELECT DISTINCT year FROM dfes ORDER BY year DESC";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $years = $sth->fetchall_arrayref( {} );
    $sth->finish();
    return $years;
}

sub process_template
{
    my $self = shift;
    my $template = shift;
    my $params = shift;
    $self->{tt}->process( $template, $params ) || croak $self->{tt}->error;
    return unless $self->{debug};
    $self->{tt}->process( $template, $params, \*STDERR );
}

sub years_xml
{
    my $self = shift;
    my $years = $self->years();
    $self->process_template( "generic.xml", { tag => 'year', objs => $years } );
}

sub sources_xml
{
    my $self = shift;
    my $sql = "SELECT * from source";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $sources = $sth->fetchall_arrayref( {} );
    $sth->finish();
    $self->process_template( "generic.xml", { tag => 'source', objs => $sources } );
}

sub keystages_xml
{
    my $self = shift;
    my $sql = "SELECT * from keystage ORDER BY age";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my $keystages = $sth->fetchall_arrayref( {} );
    $sth->finish();
    $self->process_template( "generic.xml", { tag => "keystage", objs => $keystages } );
}

sub schools_xml
{
    my $self = shift;
    my $sql = "SELECT $self->{what} $self->{from} $self->{join} $self->{select_where}";
    $self->{format} ||= "xml";
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
    my $limit = 50;
    $limit = $self->{limit} if defined $self->{limit};
    $sql .= " LIMIT $limit";
    warn "$sql\n";
    warn "ARGS: @{$self->{args}}\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @{$self->{args}} );
    my $nrows = $sth->rows;
    my $types_sth = $self->{dbh}->prepare( "SELECT type FROM school_type WHERE school_id = ?" );
    my @schools;
    while ( my $school = $sth->fetchrow_hashref )
    {
        $types_sth->execute( $school->{school_id} );
        $school->{type} = join " / ", map $_->[0], @{$types_sth->fetchall_arrayref()};
        delete $school->{location};
        push( @schools, $school );
    }
    my $nschools = $self->count();
    $nschools = $nrows if $nrows > $nschools;
    warn "nschools: $nschools\n";
    $self->process_template( 
        "school.$self->{format}", 
        { schools => \@schools, nschools => $nschools }
    );
}

1;