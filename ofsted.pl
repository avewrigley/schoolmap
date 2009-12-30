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
use DBI;
use HTML::Entities;
use lib "$Bin/lib";
require CreateSchool;

my %opts;
my @opts = qw( force! flush all school=s type=s urn=s silent pidfile! verbose );
my %types = (
    primary => qr/primary schools/i,
    secondary => qr/secondary schools/i,
    independent => qr/independent education/i,
    special => qr/special schools/i,
    college => qr/colleges/i,
);

my ( $dbh, $sc, $rsth, $ssth );

sub update_school
{
    my %school = @_;
    eval {
        my $mech = WWW::Mechanize->new();
        die "no url\n" unless $school{url};
        warn "GET $school{url}\n";
        my $resp = $mech->get( $school{url} );
        my $html = $mech->content();
        die "no HTML\n" unless $html;
        my ( $name ) = $html =~ m{<h1 class="headingStyling">(.*?)</h1>}sim;
        die "no name\n" unless $name;
        $school{name} = decode_entities( $name );
        my ( $type ) = $html =~ m{Description:\s*<span class="providerDetails">(.*?)</span>}sim;
        $school{type} = decode_entities( $type );
        die "no type\n" unless $school{type};
        warn "$school{name} ($school{type})\n";
        my @address = grep /\w/, map decode_entities( $_ ), $html =~ m{<p class="providerAddress">(.*?)</p>}gsim;
        $school{address} = join( ",", @address );
        $school{postcode} = $address[-1];
        die "no postcode ($school{address})\n" unless $school{postcode};
        $school{postcode} =~ s/^\s*//g;
        $school{postcode} =~ s/\s*$//g;
        $sc->create_school( 'ofsted', %school );
        $rsth->execute( @school{qw(ofsted_id url type)} );
    };
    if ( $@ )
    {
        warn "$school{url} FAILED: $@\n";
    }
    else
    {
        warn "$school{url} SUCCESS\n";
    }
}

# Main

my $root_url =  "http://www.ofsted.gov.uk/oxedu_providers/full/(urn)/";
$opts{pidfile} = 1;
$opts{force} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
my $logfile = "$Bin/logs/ofsted.log";
$dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
if ( $opts{flush} )
{
    for my $table ( qw( ofsted school ) )
    {
        warn "flush $table\n";
        $dbh->do( "DELETE FROM $table" );
    }
}
$sc = CreateSchool->new( dbh => $dbh );
$ssth = $dbh->prepare( "SELECT * FROM ofsted WHERE ofsted_id = ? AND ofsted_url = ? AND type = ?" );
$rsth = $dbh->prepare( "REPLACE INTO ofsted ( ofsted_id, ofsted_url, type ) VALUES ( ?, ?, ? )" );
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
if ( $opts{all} )
{
    my $sql;
    if ( $opts{force} )
    {
        # $sql = "SELECT URN FROM school_list ORDER BY URN";
        $sql = "SELECT ofsted_id FROM ofsted WHERE type = ? ORDER BY ofsted_id";
    }
    else
    {
        $sql = "SELECT URN FROM school_list LEFT JOIN school ON school_list.URN = school.ofsted_id WHERE school.ofsted_id IS NULL ORDER BY URN";
    }
    my $sth = $dbh->prepare( $sql );
    for my $type ( keys %types )
    {
        $sth->execute( $type );
        while ( my ( $urn ) = $sth->fetchrow )
        {
            warn "$urn\n";
            update_school( ofsted_id => $urn, url => "$root_url$urn" );
        }
    }
    exit;
}
if ( $opts{urn} )
{
    update_school( ofsted_id => $opts{urn}, url => "$root_url$opts{urn}" );
    exit;
}
my @types = $opts{type} ? ( $opts{type} ) : keys %types;
TYPE: for my $type ( @types )
{
    warn "searching $type schools\n";
    my $mech = WWW::Mechanize->new();
    $mech->get( 'http://www.ofsted.gov.uk/' );
    unless ( $mech->follow_link( text_regex => qr/inspection reports/i ) )
    {
        die "failed to find inspection reports\n";
    }
    unless ( $mech->follow_link( text_regex => $types{$type} ) )
    {
        die "no links match $types{$type}\n";
    }
    my $uri = $mech->uri;
    my $html = $mech->content();
    my ( $nreports ) = $html =~ /\(out of (\d+)\)/;
    warn "$nreports reports found\n";
    my $i = 0;
    my $next;
    my $next_regex = qr{\(offset\)/\d+};
    my $url_regex = qr{\(urn\)/(\d+)};
    while( 1 ) {
        my @links = $mech->find_all_links( url_regex => $url_regex );
        die "no links match $url_regex\n" unless @links;
        LINK: for my $link ( @links )
        {
            $i++;
            my $url = $link->url_abs;
            my %school = ( type => $type );
            ( $school{ofsted_id} ) = $url =~ $url_regex;
            $school{url} = $url;
            $school{name} = $link->text;
            warn "($i / $nreports) $type - $school{name}\n";
            next LINK if $opts{school} && $opts{school} ne $school{name};
            $ssth->execute( @school{qw(ofsted_id url type)} );
            my $school = $ssth->fetchrow_hashref();
            if ( ! $opts{force} && $school )
            {
                warn "already seen ...\n";
                next LINK;
            }
            update_school( %school );
            next TYPE if $opts{school} && $opts{school} eq $school{name};
        }
        unless ( $mech->follow_link( text_regex => qr/Next/ ) )
        {
            warn "no next links\n";
            last;
        }
    }
    if ( $i != $nreports )
    {
        die "ERROR: $nreports expected; $i seen\n";
    }
}
warn "$0 ($$) finished\n";
