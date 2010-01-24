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
use LWP::UserAgent;
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use HTML::Entities;
require HTML::TableExtract;
use DBI;
use lib "$Bin/lib";
require CreateSchool;
use Acronyms;
use vars qw( %types @types );

my $postcode_regex = qr{^([A-PR-UWYZ0-9][A-HK-Y0-9][AEHMNPRTVXY0-9]?[ABEHMNPRVWXY0-9]? {1,2}[0-9][ABD-HJLN-UW-Z]{2}|GIR 0AA)$}i;

sub get_types
{
    my $year = shift;
    return (
        primary => {
            type_regex => qr/$year Primary School \(Key Stage 2\)/,
            la_regex => qr/Mode=Z&Type=LA&.*?No=\d+&.*?&Phase=p/,
            school_regex => qr/Mode=Z&Type=LA.*?&Phase=p&Year=\d+&Base=a&Num=\d+/,
            pupils_index => 1,
            score_index => 16,
            details_regex => qr{<dt>Address:</dt>.*?<dd>(.*?)</dd>}sim,
        },
        secondary => {
            type_regex => qr/$year Secondary School \(GCSE and equivalent\)/,
            la_regex => qr/Mode=Z&Type=LA&.*?No=\d+&.*?&Phase=1/,
            school_regex => qr/Mode=Z&Type=LA.*?&Phase=1&Year=\d+&Base=a&Num=\d+/,
            pupils_regex => qr{<dt>Number of pupils at the end of Key Stage 4</dt>.*?<dd>(\d*)</dd>}sim,
            score_index => 10,
            table_tab => "KS4 Results",
            details_regex => qr{<dt>Address:</dt>.*?<dd>(.*?)</dd>}sim,
        },
        post16 => {
            type_regex => qr/$year School and College \(post-16\)/,
            la_regex => qr/Mode=Z&Type=LA&No=\d+&.*&Phase=2/,
            school_regex => qr/Mode=Z&Type=LA&Phase=2&Year=\d+&Base=a&Num=\d+/,
            pupils_index => 1,
            details_regex => qr{<dt>Address:</dt>.*?<dd>(.*?)</dd>}sim,
            score_index => 3,
        },
    );
}

my %opts;
my @opts = qw( year=s force flush region=s la=s school=s type=s force silent pidfile! verbose );

my ( $dbh, $sc, $acronyms, %done );

sub get_id
{
    my $url = shift;
    my ( $id ) = $url =~ m{No=(\d+)};
    return $id;
}

sub update_school
{
    my $type = shift;
    my $school_name = shift;
    my $url = shift;
    my $row = shift;
    my %school = ( name => $school_name );
    $school{dcsf_id} = get_id( $url );
    die "no id for $url\n" unless $school{dcsf_id};
    my $mech = WWW::Mechanize->new();
    $mech->get( $url );
    my $html = $mech->content();
    unless ( $html )
    {
        warn "failed to get $url\n";
        return;
    }
    my $details_regex = $types{$type}{details_regex};
    die "no details regex\n" unless $details_regex;
    my ( $details ) = $html =~ $details_regex;
    warn "Can't find details\n" and return unless $details;
    my @lines = split( /<br\s*\/>/sim, $details );
    s/\s*$// for @lines; s/^\s*// for @lines;
    @lines = grep /\w/, map decode_entities( $_ ), @lines;
    my @address;
    for my $line ( @lines )
    {
        push( @address, $line );
        if ( $line =~ $postcode_regex )
        {
            $school{postcode} = $line;
            last;
        }
    }
    $school{address} = join( ",", @address );
    unless ( $school{postcode} )
    {
        warn "combined schools ...\n";
        die "no school regex\n" unless my $school_regex = $types{$type}{school_regex};
        my @schools = $mech->find_all_links( url_regex => $school_regex );
        for my $school ( @schools )
        {
            my $url = $school->url_abs;
            my $text = $school->text;
            my $id = get_id( $url );
            warn "trying $text ($id)\n";
            if ( $done{$id} )
            {
                warn "$text done\n";
            }
            else
            {
                die "no postcode for $school{name} $school{address} ($url)\n";
            }
        }
        warn "All combined schools found\n";
        return;
    }
    $sc->create_school( 'dcsf', %school );
    my ( $score, $pupils );
    if ( my $i = $types{$type}{score_index} )
    {
        $score = $row->[$i];
        if ( $score )
        {
            $score =~ s/\s*$//; $score =~ s/^\s*//;
            unless ( $score =~ /^([\d\.]+)$/ )
            {
                # warn "'$score' is not numeric\n";
                $score = undef;
            }
        }
    }
    else
    {
        warn "no score index\n";
    }
    if ( my $regex = $types{$type}{pupils_regex} )
    {
        ( $pupils ) = $html =~ $types{$type}{pupils_regex};
    }
    elsif ( my $i = $types{$type}{pupils_index} )
    {
        $pupils = $row->[$i];
        if ( $pupils )
        {
            $pupils =~ s/\s*$//; $pupils =~ s/^\s*//;
            unless ( $pupils =~ /^(\d+)$/ )
            {
                warn "$pupils is not an integer\n";
                $pupils = undef;
            }
        }
        else
        {
            warn "no pupils\n";
        }
    }
    else
    {
        warn "no pupils index / regex\n";
    }
    return unless $score && $pupils;
    # <body onload="SmallMap('gmapSmall',13,null,null,null,50.808378717675,0.241684204290,null,2)">
    my ( $lat, $lon ) = $html =~ /SmallMap\('gmapSmall',[^,]+,[^,]+,[^,]+,[^,]+,([\d\-\.]+),([\d\-\.]+),[^,]+,[^,]+\)/;
    if ( $lat && $lon )
    {
        $school{lat} = $lat, $school{lon} = $lon;
    }
    my @acronyms = $html =~ m{<a .*?class="acronym".*?>(.*?)</a>}gism;
    #warn "\t\t\t(lat:$lat, lon:$lon, score:$score, pupils:$pupils, acronyms:@acronyms)\n";
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
        ( $min_age, $max_age ) = $age_range =~ /(\d+)-(\d+)/;
    }
    my ( $special ) = grep { $acronyms->special( $_ ) } @acronyms;
    my $select_sql = "SELECT dcsf_id FROM dcsf WHERE dcsf_id = ?";
    my $select_sth = $dbh->prepare( $select_sql );
    $select_sth->execute( $school{dcsf_id} );
    if ( $select_sth->fetchrow )
    {
        my $update_sql = <<EOF;
UPDATE dcsf SET type = ?, ${type}_url = ?, average_${type} = ?, pupils_${type} = ? WHERE dcsf_id = ?
EOF
        my $update_sth = $dbh->prepare( $update_sql );
        $update_sth->execute( $type, $url, $score, $pupils, $school{dcsf_id} );
    }
    else
    {
        my $insert_sql = <<EOF;
INSERT INTO dcsf (type,special,min_age,max_age,age_range,${type}_url,average_${type},pupils_${type},dcsf_id) VALUES(?,?,?,?,?,?,?,?)
EOF
        my $insert_sth = $dbh->prepare( $insert_sql );
        $insert_sth->execute( $type, $special, $min_age, $max_age, $age_range, $url, $score, $pupils, $school{dcsf_id} );
    }
    $done{$school{dcsf_id}} = $school_name;
}

# Main

$opts{pidfile} = 1;
$opts{year} = ( localtime )[5];
$opts{year} += 1900;
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
%types = get_types( $opts{year} );
@types = $opts{type} ? ( $opts{type} ) : keys %types;
for my $type ( @types )
{
    die "unknown type $type\n" unless $types{$type};
    warn "getting performance tables for $type\n";
    my $mech = WWW::Mechanize->new();
    $mech->get( 'http://www.dcsf.gov.uk/' );
    unless ( $mech->follow_link( text_regex => qr/performance tables/i ) )
    {
        die "failed to find performance tables\n";
    }
    warn "performance tables at ", $mech->uri(), "\n";
    my $type_regex = $types{$type}{type_regex};
    warn "Trying $type_regex ...\n";
    if ( ! $mech->follow_link( text_regex => $type_regex ) )
    {
        warn "failed to find link matching $type_regex!\n";
        next;
    }
    warn $mech->uri(), "\n";
    my $success = 0;
    my @regions = $mech->find_all_links( url_regex => qr/\/region\d+/ );
    for my $region ( @regions )
    {
        my $url = $region->url_abs;
        my $response = $mech->get( $url );
        unless ( $response->is_success )
        {
            warn "failed to get $url\n";
            next;
        }
        my $content = $response->content;
        my ( $title ) = $content =~ m{<title>(.*?)</title>}sim;
        my $region_name = $title;
        warn "$type\t$title ($url)\n";
        next if $opts{region} && $opts{region} ne $region_name;
        die "no la regex\n" unless my $la_regex = $types{$type}{la_regex};
        my @las = $mech->find_all_links( url_regex => $la_regex );
        for my $la ( @las )
        {
            my $url = $la->url_abs;
            my $la_name = $la->text;
            next if $opts{la} && $opts{la} ne $la_name;
            warn "$type\t$region_name\t$la_name ($url)\n";
            $mech->get( $url );
            if ( $types{$type}{table_tab} )
            {
                warn "click on $types{$type}{table_tab}\n";
                unless ( $mech->follow_link( text => $types{$type}{table_tab} ) )
                {
                    warn "failed\n";
                    next;
                }
            }
            my %url_seen = ();
            while ( 1 )
            {
                my $url = $mech->uri;
                if ( $url_seen{$url}++ )
                {
                    warn "$url already seen\n";
                    last;
                }
                my $html = $mech->content();
                my $te = HTML::TableExtract->new( keep_html => 1 );
                $te->parse( $html );
                my @tables = $te->tables;
                foreach my $ts ( $te->tables ) {
                    foreach my $row ( $ts->rows ) {
                        my $school_html = $row->[0];
                        next unless $school_html;
                        my ( $school_url, $school_name ) = $school_html =~ m{<a .*?href="(.*?)".*?>(.*?)</a>}sim;
                        next unless $school_name && $school_url;
                        next unless $school_name && $school_name =~ /\S/;
                        $school_url = decode_entities( $school_url );
                        my $u1 = URI::URL->new( $school_url, $url );
                        $school_url = $u1->abs;
                        next if $opts{school} && $opts{school} ne $school_name;
                        # warn "$type\t$region_name\t$la_name\t$school_name ($school_url)\n";
                        warn "\t$school_name ($school_url)\n";
                        eval {
                            update_school( $type, $school_name, $school_url, $row );
                        };
                        if ( $@ )
                        {
                            warn "$school_name FAILED: $@\n";
                        }
                    }
                }
                if ( $mech->follow_link( text_regex => qr/Next/ ) )
                {
                    my $next_url = $mech->uri;
                    warn "Next page ($next_url) ...\n";
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
warn "$0 ($$) finished\n";
