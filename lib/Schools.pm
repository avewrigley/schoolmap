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
    my @where = ( 
        "school.postcode = postcode.code", 
        "dfes.dfes_id = school.dfes_id",
    );
    my @from = ( "dfes", "postcode", "school" );
    my $type = $self->{type};
    $self->{from} = "FROM " . join( ",", @from );
    if ( $self->{minLon} && $self->{maxLon} && $self->{minLat} && $self->{maxLat} )
    {
        push( 
            @where,
            (
                "postcode.lon > $self->{minLon}",
                "postcode.lon < $self->{maxLon}",
                "postcode.lat > $self->{minLat}",
                "postcode.lat < $self->{maxLat}",
            )
        );
    }
    $self->{where} = \@where;
    $self->{tt} = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    return $self;
}

sub xml
{
    my $self = shift;
    if ( exists $self->{count} )
    {
        $self->count_xml();
    }
    else
    {
        $self->schools_xml();
    }
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

sub process_template
{
    my $self = shift;
    my $template = shift;
    my $params = shift;
    $self->{tt}->process( $template, $params ) || croak $self->{tt}->error;
    return unless $self->{debug};
    $self->{tt}->process( $template, $params, \*STDERR );
}

sub schools_xml
{
    my $self = shift;
    my @args;
    my @what = ( "*" );
    if ( $self->{centreX} && $self->{centreY} )
    {
        push( 
            @what, 
            "GLength(LineStringFromWKB(LineString(AsBinary(GeomFromText(?)), AsBinary(postcode.location)))) AS distance",
        );
        push( @args, "POINT( $self->{centreX} $self->{centreY} )" );
    }
    my $what = join( ",", @what );
    my $join = " LEFT JOIN ofsted ON ( school.ofsted_id = ofsted.ofsted_id ) ";
    my @where = @{$self->{where}};
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    my $sql = "SELECT $what $self->{from} $join $where";
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
    warn "ARGS: @args\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @args );
    my @schools;
    while ( my $school = $sth->fetchrow_hashref )
    {
        delete $school->{location};
        push( @schools, $school );
    }
    $self->process_template( 
        "school.$self->{format}", 
        { schools => \@schools }
    );
}

sub count_xml
{
    my $self = shift;
    my @where = @{$self->{where}};
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    my $sql = "SELECT COUNT( * ) $self->{from} $where";
    $self->{format} ||= "xml";
    warn "$sql\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    my ( $count ) = $sth->fetchrow;
    $self->process_template( 
        "count.xml", 
        { count => $count }
    );
}

1;
