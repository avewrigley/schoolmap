package Schools;

use strict;
use warnings;

use Carp;
use HTML::Entities qw( encode_entities );
use Template;
use Data::Dumper;
use JSON;
use FindBin qw( $Bin );
use File::Slurp;
require Geo::Postcode;
require Geo::Coder::OpenCage;
require DBI;
use YAML qw( LoadFile );

my %format2content_type = (
    "kml" => "application/vnd.google-earth.kml+xml",
    "json" => "application/json",
    "georss" => "application/rss+xml+geo",
    "xml" => "application/xml",
);

my @required = qw( config_file template_dir );

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    for my $key ( @required )
    {
        die "required arg $key not provided\n" unless exists $self->{$key};
    }
    # $self->{debug} = 1;
    $self->{config} = LoadFile( $self->{config_file} );
    $self->{tt} = Template->new( INCLUDE_PATH => $self->{template_dir} );
    $self->{geopostcode} = Geo::Postcode->new( );
    $self->{geocoder} = Geo::Coder::OpenCage->new( api_key => $self->{config}{open_cage_api_key} );
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    return $self;
}

sub render_as
{
    my $self = shift;
    my $format = shift;

    my $schools = $self->_get_schools();
    my $content_type = $format2content_type{$format};
    my $content = '';
    if ( $format eq 'json' )
    {
        $content = to_json( $schools );
    }
    else
    {
        $self->{tt}->process( "school.$self->{parameters}{format}", $schools, \$content ) || croak $self->{tt}->error;
    }
    return ( $content, $content_type );
}

sub get_phases
{
    my $self = shift;
    my ( $geo_where, $geo_args ) = $self->_geo_where();
    return [] unless @$geo_where;
    my $where = "WHERE phase IS NOT NULL AND " . join( " AND ", @$geo_where );
    my @phases = ( "all" );
    my %join = ( "performance" => "ON school.ofsted_id = performance.ofsted_id" );
    my $join = join( " ", map "JOIN $_ $join{$_}", keys %join );
    my $sql = "SELECT DISTINCT phase FROM school $join $where";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @$geo_args );
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

sub _where
{
    my $self = shift;

    my @args = ();
    my @where = ();

    my ( $geo_where, $geo_args ) = $self->_geo_where();
    if ( @$geo_where )
    {
        push( @where, @$geo_where );
        push( @args, @$geo_args );
    }
    if ( my $school_phase = $self->{parameters}{phase} )
    {
        push( @where, "school.phase = ?" );
        push( @args, $school_phase );
    }
    else
    {
        push( @where, "school.phase IS NOT NULL" );
    }
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    return ( $where, @args );
}

sub _geo_where
{
    my $self = shift;
    return ( [], [] ) unless $self->{parameters}{minLon} && $self->{parameters}{maxLon} && $self->{parameters}{minLat} && $self->{parameters}{maxLat};
    my @where = ( "school.lon > ?", "school.lon < ?", "school.lat > ?", "school.lat < ?" );
    my @args = ( $self->{parameters}{minLon}, $self->{parameters}{maxLon}, $self->{parameters}{minLat}, $self->{parameters}{maxLat} );
    return ( \@where, \@args );
}

sub _get_schools
{
    my $self = shift;
    my @what = ( "school.*" ,"performance.*" );
    my ( $where, @args ) = $self->_where;
    if ( $self->{parameters}{lat} && $self->{parameters}{lon} )
    {
        my $distance_sql = <<EOF;
(((acos(sin((?*pi()/180)) * sin((lat*pi()/180))+cos((?*pi()/180)) * cos((lat*pi()/180)) * cos(((?-lon)*pi()/180))))*180/pi())*60*1.1515*1.609344) as distance
EOF
        push( @what, $distance_sql );
        unshift( @args, $self->{parameters}{lat}, $self->{parameters}{lat}, $self->{parameters}{lon} );
    }
    my $what = join( ",", @what );
    my %join = ( "performance" => "ON school.ofsted_id = performance.ofsted_id" );
    my $join = join( " ", map "JOIN $_ $join{$_}", keys %join );
    my $sql = <<EOF;
SELECT SQL_CALC_FOUND_ROWS $what FROM school $join
    $where
EOF
    warn $sql;
    if ( $self->{parameters}{order_by} )
    {
        if ( $self->{parameters}{order_by} eq 'distance' )
        {
            $sql .= " ORDER BY distance";
        }
        else
        {
            $sql .= " ORDER BY $self->{parameters}{order_by} DESC";
        }
    }
    if ( defined $self->{parameters}{limit} )
    {
        $sql .= " LIMIT $self->{parameters}{limit}";
    }
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
    my $phases = $self->get_phases();
    return { nschools => $nschools, schools => \@schools, phases => $phases };
}

sub _get_location
{
    my $self = shift;
    my $school = shift;
    my %opts = @_;

    if ( $school->{lat} && $school->{lon} )
    {
        return( $school->{lat}, $school->{lon} );
    }
    my @coords = $self->{geopostcode}->coords( $school->{postcode} );
    return @coords if @coords == 2 && $coords[0] && $coords[1];
    my $response = $self->{geocoder}->geocode( location => $school->{postcode} );
    my @results = @{$response->{results}};
    my $location = $results[0]{geometry};
    if ( $location )
    {
        $self->{geopostcode}->add( $school->{postcode}, $location->{lat}, $location->{lng} );
        return ( $location->{lat}, $location->{lng} );
    }
    else
    {
        warn "failed to get location for $school->{postcode}\n";
    }
    die "no lat / lon\n";
}

sub get_school
{
    my $self = shift;
    my $ofsted_id = shift;
    my $sth = $self->{dbh}->prepare( <<SQL );
SELECT * FROM school WHERE ofsted_id = ?
SQL
    $sth->execute( $ofsted_id );
    my $school = $sth->fetchrow_hashref;
    return $school;
}

sub remove_non_ascii_characters
{
    my $str = shift;
    $str =~ s/(.)/(ord($1) > 127) ? "?" : $1/egs;
    return $str;
}

sub sanitise_school
{
    my $school = shift;
    foreach my $key ( keys %$school )
    {
        $school->{$key} = remove_non_ascii_characters( $school->{$key} );
    }
}

sub create_school
{
    my $self = shift;
    my %school = @_;

    die "no ofsted_id" unless $school{ofsted_id};
    die "no name" unless $school{name};
    die "no postcode" unless $school{postcode};
    my $postcode = $school{postcode};
    $school{postcode} = uc( $school{postcode} );
    $school{postcode} =~ s/[^0-9 A-Z]//g;
    ( $school{lat}, $school{lon} ) = $self->_get_location( \%school );
    sanitise_school( \%school );
    my $isth = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( ofsted_id, ofsted_url, name, type, phase, postcode, address, lat, lon ) VALUES ( ?,?,?,?,?,?,?,?,? )
SQL
    $isth->execute( @school{qw( ofsted_id url name type phase postcode address lat lon )} );
}

1;
