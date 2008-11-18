package Acronyms;

use DBI;

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
    "SEN BES" => "SEN Specialism Behaviour, Emotional and Social Development",
    "SEN C&I" => "SEN Specialism Communication and Interaction",
    "SEN C&L" => "SEN Specialism Cognition and Learning",
    "SEN S&P" => "SEN Specialism Sensory and/or Physical Needs",
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
    return %specials;
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
    my $sth = $self->{dbh}->prepare( "SELECT min_age FROM school,dcsf WHERE school.dcsf_id = dcsf.dcsf_id AND school.ofsted_id IS NOT NULL AND min_age IS NOT NULL AND school.ofsted_type IS NOT NULL ORDER BY min_age LIMIT 1" );
    $sth->execute;
    my ( $min_age ) = $sth->fetch;
    my $sth = $self->{dbh}->prepare( "SELECT max_age FROM school,dcsf WHERE school.dcsf_id = dcsf.dcsf_id AND school.ofsted_id IS NOT NULL AND max_age IS NOT NULL AND school.ofsted_type IS NOT NULL ORDER BY max_age DESC LIMIT 1" );
    $sth->execute;
    my ( $max_age ) = $sth->fetch;
    return ( $min_age, $max_age );
}

1;
