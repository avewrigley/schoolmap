package Apache2::Schools;

use strict;
use warnings;

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const -compile => qw(OK);
require Schools;

my $logfile = '/var/www/www.schoolmap.org.uk/logs/schools_modperl.log';

sub params
{
    my $r = shift;
    return map { split( "=", $_, 2 ) } split( "&", decode( $r->args() ) );
}

sub decode
{
    my $str = shift;
    $str =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    return $str;
}

sub handler
{
    my $r = shift;
    
    warn "open $logfile\n";
    open( STDERR, ">>$logfile" ) or warn "failed to open $logfile: $!\n";;
    $r->content_type('text/xml');
    my %params = params( $r );
    warn map "$_ = $params{$_}\n", keys %params;
    my $ofsted = Schools->new( %params );
    warn "$$ at ", scalar( localtime ), "\n";
    $ofsted->xml();
    return Apache2::Const::OK;
}

1;
