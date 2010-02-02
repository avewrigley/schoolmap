package Schools;

use strict;
use warnings;

use Carp;
use HTML::Entities qw( encode_entities );
use Template;
use Data::Dumper;
use JSON;

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    require DBI;
    # $self->{debug} = 1;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{tt} = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    return $self;
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

sub json
{
    my $self = shift;
    my $schools = $self->get_schools();
    print to_json( $schools );
}

sub phases
{
    my $self = shift;
    print to_json( $self->get_phases );
}

sub get_phases
{
    my $self = shift;
    my ( $where, $from, @args ) = $self->geo_where();
    my @phases = ( "all" );
    my $sql = "SELECT DISTINCT phase FROM $from $where";
    warn "$sql\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @args );
    while ( my ( $phase ) = $sth->fetchrow )
    {
        push( @phases, $phase );
    }
    return \@phases;
}

sub get_order_bys
{
    my $self = shift;
    return [
        { val => "", str => "-" },
        { val => "distance", str => "Distance" },
        { val => "primary", str => "Key stage 2 results" },
        { val => "ks3", str => "Key stage 3 results" },
        { val => "secondary", str => "GCSE results" },
        { val => "post16", str => "GCE and VCE results" },
    ];
}

sub xml
{
    my $self = shift;
    my $schools = $self->get_schools();
    $self->{format} ||= "xml";
    $self->process_template( "school.$self->{format}", $schools );
}

sub where
{
    my $self = shift;
    my @args;
    my @where = ( );
    if ( $self->{minLon} && $self->{maxLon} && $self->{minLat} && $self->{maxLat} )
    {
        push( 
            @where,
            (
                "school.lon > ?",
                "school.lon < ?",
                "school.lat > ?",
                "school.lat < ?",
            )
        );
        push( @args, $self->{minLon}, $self->{maxLon}, $self->{minLat}, $self->{maxLat} );
    }
    if ( my $school_phase = $self->{phase} )
    {
        push( @where, "school.phase = ?" );
        push( @args, $school_phase );
    }
    else
    {
        push( @where, "school.phase IS NOT NULL" );
    }
    if ( $self->{find_school} )
    {
        push( @where, 'school.name LIKE ?' );
        push( @args, "%" . $self->{find_school} ."%" );
    }
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    return ( $where, @args );
}

sub geo_where
{
    my $self = shift;
    return ( "", "school" ) unless $self->{minLon} && $self->{maxLon} && $self->{minLat} && $self->{maxLat};
    my @where = (
        "school.lon > ?",
        "school.lon < ?",
        "school.lat > ?",
        "school.lat < ?",
    );
    my @args = ( $self->{minLon}, $self->{maxLon}, $self->{minLat}, $self->{maxLat} );
    my $where = "WHERE " . join( " AND ", @where );
    return ( $where, "school", @args );
}

sub get_schools
{
    my $self = shift;
    my @what = ( "school.*,dcsf.*" );
    my $what = join( ",", @what );
    my ( $where, @args ) = $self->where;
    my @from = ( "school" );
    my %join = ( "dcsf" => "ON school.dcsf_id = dcsf.dcsf_id" );
    my $from = join( ",", @from );
    my $join = join( " ", map "LEFT JOIN $_ $join{$_}", keys %join );
    my $sql = <<EOF;
SELECT SQL_CALC_FOUND_ROWS $what FROM $from $join
    $where
EOF
    if ( $self->{order_by} )
    {
        $sql .= " ORDER BY average_$self->{order_by} DESC";
    }
    else
    {
        $sql .= " ORDER BY name";
    }
    unless ( $self->{nolimit} )
    {
        my $limit = 50;
        $limit = $self->{limit} if defined $self->{limit};
        $sql .= " LIMIT $limit";
    }
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
    $sth = $self->{dbh}->prepare( "SELECT FOUND_ROWS();" );
    $sth->execute();
    my ( $nschools ) = $sth->fetchrow();
    warn "NROWS: $nschools\n";
    return { nschools => $nschools, schools => \@schools };
}

1;
