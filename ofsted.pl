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
use lib "$Bin/lib";
require CreateSchool;

my %opts;
my @opts = qw( flush type=s force silent pidfile! verbose );
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
my $rsth = $dbh->prepare( "REPLACE INTO ofsted ( ofsted_id, ofsted_url ) VALUES ( ?, ? )" );
unless ( $opts{verbose} )
{
    open( STDERR, ">>$logfile" ) or die "can't write to $logfile\n";
}
my $mech = WWW::Mechanize->new();
for my $type ( keys %types )
{
    $mech->get( 'http://www.ofsted.gov.uk/' );
    $mech->follow_link( text_regex => qr/inspection reports/i );
    $mech->follow_link( text_regex => $types{$type} );
    my $uri = $mech->uri;
    my $html = $mech->content();
    my ( $nreports ) = $html =~ /\(out of (\d+)\)/;
    $uri =~ s/maxResultPerPage=10/maxResultPerPage=$nreports/;
    $mech->get( $uri );
    my @links = $mech->find_all_links(
        url_regex => qr/urn=(\d+)/
    );
    for my $link ( @links )
    {
        my %school;
        $school{url} = $link->url_abs;
        $school{name} = $link->text;
        warn "$type - $school{name}\n";
        eval {
            warn "GET $school{url}\n";
            $mech->get( $school{url} );
            my $html = $mech->content();
            die "no HTML\n" unless $html;
            ( $school{ofsted_id} ) = $html =~ m{<th>Unique reference number</th>\s*<td>(\d+)</td>}sim;
            die "no ofsted_id\n" unless $school{ofsted_id};
            warn "ofsted_id: $school{ofsted_id}\n";
            my ( $address ) = $html =~ m{<p class="address">(.*?)</p>}sim;
            warn "address: $address\n";
            die "no address\n" unless $address;
            my @address = grep /\S/, $address =~ m{<span class="line">(.*?)</span>}gsim;
            $school{address} = join( ",", @address );
            warn "address: $school{address}\n";
            $school{postcode} = $address[-1];
            warn "postcode: $school{postcode}\n";
            die "no postcode ($school{address})\n" unless $school{postcode};
            $school{postcode} =~ s/\s*//g;
            warn "POSTCODE: $school{postcode}\n";
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
}
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
warn "$0 ($$) finished\n";
