#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use FindBin qw( $Bin );
use WWW::Mechanize;
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use HTML::Entities;
require HTML::TableExtract;
use DBI;
use lib "$Bin/lib";
require CreateSchool;
use Acronyms;

my $postcode_regex = qr{^([A-PR-UWYZ0-9][A-HK-Y0-9][AEHMNPRTVXY0-9]?[ABEHMNPRVWXY0-9]? {1,2}[0-9][ABD-HJLN-UW-Z]{2}|GIR 0AA)$}i;

my %types = (
    primary => {
        type_regex => qr/2007 Primary School \(Key Stage 2\)/i,
        la_regex => qr/Mode=Z&Type=LA&No=\d+&.*&Phase=p/,
        pupils_index => 1,
        score_index => 15,
    },
    ks3 => {
        type_regex => qr/2007 Secondary School \(Key Stage 3\)/i,
        la_regex => qr/Mode=Z&Type=LA&No=\d+&.*&Phase=k/,
        pupils_index => 1,
        score_index => 15,
    },
    secondary => {
        type_regex => qr/2007 Secondary School \(GCSE and equivalent\)/i,
        la_regex => qr/Mode=Z&Type=LA&No=\d+&.*&Phase=1/,
        pupils_index => 1,
        score_index => 15,
    },
    post16 => {
        type_regex => qr/2007 School and College \(post-16\)/i,
        la_regex => qr/Mode=Z&Type=LA&No=\d+&.*&Phase=2/,
        pupils_index => 1,
        score_index => 3,
    },
);
my %opts;
my @opts = qw( force flush region=s la=s type=s force silent pidfile! verbose );

my ( $dbh, $sc, $acronyms );

sub update_school
{
    my $type = shift;
    my $school_name = shift;
    my $url = shift;
    my $row = shift;
    my %school = ( name => $school_name, dcsf_type => $type );
    ( $school{dcsf_id} ) = $url =~ m{No=(\d+)};
    my $mech = WWW::Mechanize->new();
    $mech->get( $url );
    my $html = $mech->content();
    my ( $details ) = $html =~ m{<dl id="details">(.*?)</dl>}sim;
    my @dds = grep /\w/, map decode_entities( $_ ), $details =~ m{<dd>([^<]*?)</dd>}gi;
    my @address;
    for my $dd ( @dds )
    {
        push( @address, $dd );
        if ( $dd =~ $postcode_regex )
        {
            $school{postcode} = $dd;
            last;
        }
    }
    $school{address} = join( ",", @address );
    unless ( $school{postcode} )
    {
        die "no postcode for $school{name} $school{address} ($url)\n";
    }
    $sc->create_school( 'dcsf', %school );
    my ( $score, $pupils );
    if ( my $i = $types{$type}{score_index} )
    {
        $score = $row->[$i];
    }
    else
    {
        die "no score index\n";
    }
    die "no score\n" unless $score;
    if ( my $i = $types{$type}{pupils_index} )
    {
        $pupils = $row->[$i];
    }
    else
    {
        die "no pupils index\n";
    }
    die "no pupils\n" unless $pupils;
    my @acronyms = $html =~ m{<a .*?class="acronym".*?>(.*?)</a>}gism;
    my $dsth = $dbh->prepare( "DELETE FROM acronym WHERE dcsf_id = ?" );
    my $isth = $dbh->prepare( "INSERT INTO acronym ( dcsf_id, acronym, type ) VALUES ( ?,?,? )" );
    $dsth->execute( $school{dcsf_id} );
    for my $acronym ( @acronyms )
    {
        $isth->execute( $school{dcsf_id}, $acronym, $type );
    }
    my ( $age_range ) = grep /\d+-\d+/, @acronyms;
    my ( $min_age, $max_age );
    if ( $age_range )
    {
        warn "age range: $age_range\n";
        ( $min_age, $max_age ) = $age_range =~ /(\d+)-(\d+)/;
        warn "min age: $min_age\n";
        warn "max age: $max_age\n";
    }
    my ( $special ) = grep { $acronyms->special( $_ ) } @acronyms;
    warn "special: $special\n" if $special;
    my $select_sql = "SELECT * FROM dcsf WHERE dcsf_id = ?";
    my $select_sth = $dbh->prepare( $select_sql );
    $select_sth->execute( $school{dcsf_id} );
    my @row = $select_sth->fetchrow;
    if ( @row )
    {
        my $update_sql = <<EOF;
UPDATE dcsf SET special=?, min_age=?, max_age=?, age_range=?, ${type}_url=?, average_${type}=?, pupils_${type}=?, type=? WHERE dcsf_id = ?
EOF
        my $update_sth = $dbh->prepare( $update_sql );
        $update_sth->execute( $special, $min_age, $max_age, $age_range, $url, $score, $pupils, $type, $school{dcsf_id} );
    }
    else
    {
        my $insert_sql = <<EOF;
INSERT INTO dcsf (special,min_age,max_age,age_range,${type}_url,average_${type},pupils_${type},type,dcsf_id) VALUES(?,?,?,?,?,?,?,?,?)
EOF
        my $insert_sth = $dbh->prepare( $insert_sql );
        $insert_sth->execute( $special, $min_age, $max_age, $age_range, $url, $score, $pupils, $type, $school{dcsf_id} );
    }
}

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
my $logfile = "$Bin/logs/dcsf.log";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
$sc = CreateSchool->new( dbh => $dbh );
$acronyms = Acronyms->new();
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
my $mech = WWW::Mechanize->new();
my $te = HTML::TableExtract->new();

my @types = $opts{type} ? ( $opts{type} ) : keys %types;
for my $type ( @types )
{
    warn "getting performance tables for $type\n";
    $mech->get( 'http://www.dcsf.gov.uk/' );
    unless ( $mech->follow_link( text_regex => qr/performance tables/i ) )
    {
        die "failed to find performance tables\n";
    }
    unless ( $mech->follow_link( text_regex => $types{$type}{type_regex} ) )
    {
        die "failed to find $type performance tables ($types{$type})\n";
    }
    my @regions = $mech->find_all_links( url_regex => qr/\/region\d+/ );
    for my $region ( @regions )
    {
        my $url = $region->url_abs;
        my $text = $region->text;
        warn "\t$text\n";
        next if $opts{region} && $opts{region} ne $text;
        $mech->get( $url );
        die "no la regex\n" unless my $la_regex = $types{$type}{la_regex};
        my @las = $mech->find_all_links( url_regex => $la_regex );
        for my $la ( @las )
        {
            my $url = $la->url_abs;
            my $text = $la->text;
            next if $opts{la} && $opts{la} ne $text;
            warn "\t\t$text\n";
            $mech->get( $url );
            while ( 1 )
            {
                my $html = $mech->content();
                $te->parse( $html );
                foreach my $ts ( $te->tables ) {
                    foreach my $row ( $ts->rows ) {
                        my $school_name = $row->[0];
                        next unless $school_name && $school_name =~ /\S/;
                        $school_name =~ s/^\s*//;
                        $school_name =~ s/\s*$//;
                        my ( $school_link ) = $mech->find_all_links( text => $school_name );
                        next unless $school_link;
                        my $url = $school_link->url_abs;
                        warn "\t\t\t$school_name\n";
                        eval {
                            update_school( $type, $school_name, $url, $row );
                        };
                        if ( $@ )
                        {
                            warn "$school_name FAILED: $@\n";
                        }
                    }
                }
                if ( $mech->follow_link( text_regex => qr/Next \d+ schools/ ) )
                {
                    warn "Next page ...\n";
                }
                else
                {
                    warn "no next links\n";
                    last;
                }
            }
        }
    }
}
