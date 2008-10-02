package Schools;

use strict;
use warnings;

use Carp;
use HTML::Entities qw( encode_entities );
use Template;
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    warn Dumper $self;
    require DBI;
    # $self->{debug} = 1;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{tt} = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    return $self;
}

sub xml
{
    my $self = shift;
    $self->schools_xml();
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
    my $what = join( ",", @what );
    my @where = ( "school.postcode = postcode.code" );
    if ( $self->{order_by} )
    {
        push( @where, "average_$self->{order_by} IS NOT NULL" );
    }
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
    if ( $self->{ofsted} eq 'yes' )
    {
        push( @where, "school.ofsted_id IS NOT NULL" );
    }
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    my @from = ( "dfes", "postcode", "school" );
    $self->{from} = "FROM " . join( ",", @from );
    my $sql = <<EOF;
SELECT SQL_CALC_FOUND_ROWS $what FROM postcode, school 
    LEFT JOIN ofsted ON ( school.ofsted_id = ofsted.ofsted_id )
    LEFT JOIN dfes ON ( school.dfes_id = dfes.dfes_id )
    $where
EOF
    $self->{format} ||= "xml";
    if ( $self->{order_by} )
    {
        $sql .= " ORDER BY average_$self->{order_by} DESC";
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
    my $sth = $self->{dbh}->prepare( "SELECT FOUND_ROWS();" );
    $sth->execute();
    my ( $nschools ) = $sth->fetchrow();
    warn "NROWS: $nschools\n";
    $self->process_template( 
        "school.$self->{format}", 
        { nschools => $nschools, schools => \@schools }
    );
}

1;
