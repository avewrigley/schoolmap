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
my @opts = qw( force flush type=s force silent pidfile! verbose );
my %types = (
    primary => qr/primary schools/i,
    secondary => qr/secondary schools/i,
    independent => qr/independent education/i,
);

my ( $dbh, $sc );

# Main

$opts{pidfile} = 1;
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
my $ssth = $dbh->prepare( "SELECT * FROM ofsted WHERE ofsted_id = ? AND ofsted_url = ?" );
my $rsth = $dbh->prepare( "REPLACE INTO ofsted ( ofsted_id, ofsted_url ) VALUES ( ?, ? )" );
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
for my $type ( keys %types )
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
            my %school;
            ( $school{ofsted_id} ) = $url =~ $url_regex;
            $school{url} = $url;
            $school{name} = $link->text;
            warn "($i / $nreports) $type - $school{name}\n";
            $ssth->execute( @school{qw(ofsted_id url)} );
            my $school = $ssth->fetchrow_hashref();
            if ( ! $opts{force} && $school )
            {
                warn "already seen ...\n";
                next LINK;
            }
            eval {
                my $mech = WWW::Mechanize->new();
                warn "GET $school{url}\n";
                $mech->get( $school{url} );
                my $html = $mech->content();
                die "no HTML\n" unless $html;
                my @address = grep /\w/, map decode_entities( $_ ), $html =~ m{<p class="providerAddress">(.*?)</p>}gsim;
                $school{address} = join( ",", @address );
                $school{postcode} = $address[-1];
                die "no postcode ($school{address})\n" unless $school{postcode};
                $school{postcode} =~ s/^\s*//g;
                $school{postcode} =~ s/\s*$//g;
                $sc->create_school( 'ofsted_id', %school );
                $rsth->execute( @school{qw(ofsted_id url)} );
            };
            if ( $@ )
            {
                warn "$school{name} FAILED: $@\n";
            }
            else
            {
                warn "$school{name} SUCCESS\n";
            }
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
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
warn "$0 ($$) finished\n";
