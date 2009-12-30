package Acronyms;

use DBI;
use strict;
use warnings;

my $where = "school.ofsted_id = ofsted.ofsted_id";
my %specials = (
    A => "Arts",
    "B&E" => "Business and Enterprise",
    E => "Engineering",
    H => "Humanities",
    L => "Languages",
    "M&C" => "Mathematics and Computing",
    Mu => "Music",
    Sc => "Science",
    Sp => "Sports",
    T => "Technology",
    V => "Vocational",
    "SEN BES" => "SEN: Behaviour, Emotional and Social Development",
    "SEN C&I" => "SEN: Communication and Interaction",
    "SEN C&L" => "SEN: Cognition and Learning",
    "SEN S&P" => "SEN: Sensory and/or Physical Needs",
    LePP => "Leading Edge",
    RATL => "Raising Achievement Transforming Learning",
    Ts => "Training School",
    YST => "Youth Sport Trust (YST) School Consultant Programme",
);


sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    return $self;
}

sub specials
{
    my $self = shift;
    my $sth = $self->{dbh}->prepare( "SELECT DISTINCT acronym FROM acronym,school,ofsted WHERE acronym.dcsf_id = school.dcsf_id AND $where" );
    $sth->execute;
    my @acronyms;
    my %s;
    while ( my ( $a ) = $sth->fetchrow )
    {
        $s{$a} = $specials{$a} if exists $specials{$a};
    }
    return \%s;

}

sub special
{
    my $self = shift;
    my $abbr = shift;
    return $specials{$abbr};
}

sub age_range
{
    my $self = shift;
    my $sth = $self->{dbh}->prepare( "SELECT min_age FROM school,dcsf,ofsted WHERE min_age IS NOT NULL AND school.dcsf_id = dcsf.dcsf_id AND $where ORDER BY min_age LIMIT 1" );
    $sth->execute;
    my ( $min_age ) = $sth->fetch;
    $sth = $self->{dbh}->prepare( "SELECT max_age FROM school,dcsf,ofsted WHERE max_age IS NOT NULL AND school.dcsf_id = dcsf.dcsf_id AND $where ORDER BY max_age DESC LIMIT 1" );
    $sth->execute;
    my ( $max_age ) = $sth->fetch;
    return [ $min_age, $max_age ];
}

1;
