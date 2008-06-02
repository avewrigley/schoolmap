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

my %opts;
my @opts = qw( flush type=s force silent pidfile! verbose );
my %types = (
    primary => qr/primary schools/i,
    secondary => qr/secondary schools/i,
    independent => qr/independent education/i,
);

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
my $logfile = "$Bin/logs/ofsted.log";
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my $ssth = $dbh->prepare( "SELECT school_id FROM school WHERE postcode = ? AND name = ?" );
my $rsth = $dbh->prepare( "REPLACE INTO ofsted ( school_id, ofsted_url, ofsted_school_id ) VALUES ( ?, ?, ? )" );
unless ( $opts{verbose} )
{
    open( STDERR, ">>$logfile" ) or die "can't write to $logfile\n";
}
my $mech = WWW::Mechanize->new();
for my $type ( keys %types )
{
    $mech->get( 'http://www.ofsted.gov.uk/' );
    warn $mech->uri, "\n";
    $mech->follow_link( text_regex => qr/inspection reports/i );
    warn "\t", $mech->uri, "\n";
    $mech->follow_link( text_regex => $types{$type} );
    warn "\t\t", $mech->uri, "\n";
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
        my $url = $link->url_abs;
        my $name = $link->text;
        warn "\t\t\t$name ($url)\n";
        eval {
            $mech->get( $url );
            my $html = $mech->content();
            die "no HTML\n" unless $html;
            open( FH, ">foo" );
            print FH $html;
            close FH;
            my ( $ofsted_id ) = $html =~ m{<th>Unique reference number</th>\s*<td>(\d+)</td>}sim;
            die "no ofsted_id\n" unless $ofsted_id;
            warn "ofsted_id: $ofsted_id\n";
            my ( $address ) = $html =~ m{<p class="address">(.*?)</p>}sim;
            die "no address\n" unless $address;
            my ( $postcode ) = $address =~ m{<span class="line">([A-Z]+[0-9]+([A-Z]+)? [1-9]+[A-Z]+)\s*</span>};
            die "no postcode\n" unless $postcode;
            $postcode =~ s/\s*//g;
            $ssth->execute( $postcode, $name );
            my $school = $ssth->fetchrow_hashref();
            die "can't find school for $name ($postcode)\n" unless $school;
            warn "school: $school->{school_id}\n";
            $rsth->execute( $school->{school_id}, $url, $ofsted_id );
        };
        if ( $@ )
        {
            warn "$url FAILED: $@\n";
        }
        else
        {
            warn "$url SUCCESS\n";
        }
    }
}
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
warn "$0 ($$) finished\n";
