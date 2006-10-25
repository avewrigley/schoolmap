package Apache::Schools;

use strict;
use warnings;

use Apache;
use Apache::Request;
use Apache::Constants qw/:common/;
require Schools;
my $logfile = '/var/www/www.schoolmap.org.uk/logs/schools.log';
sub handler
{
    my $r = Apache::Request->new( shift );
    warn "open $logfile\n";
    open( STDERR, ">>$logfile" ) or warn "failed to open $logfile: $!\n";;
    my @params = $r->param;
    warn "params: @params\n";
    my %params = map { $_ => $r->param( $_ ) } $r->param;
    warn map "$_ = $params{$_}\n", keys %params;
    my $ofsted = Schools->new( %params );
    warn "$$ at ", scalar( localtime ), "\n";
    if ( $params{types} )
    {
        $r->send_http_header('text/plain');
        $r->print( $ofsted->types() );
    }
    else
    {
        $r->send_http_header('text/xml');
        $r->print( $ofsted->schools_xml() );
    }
    return OK;
}

1;
