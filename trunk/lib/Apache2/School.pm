package Apache2::School;

use strict;
use warnings;

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const -compile => qw(OK);
require School;

my $logfile = '/var/www/www.schoolmap.org.uk/logs/school_modperl.log';

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
    $r->content_type('text/html');
    my %params = params( $r );
    warn map "$_ = $params{$_}\n", keys %params;
    my $path_info = $r->path_info();
    my ( $school_id ) = $path_info =~ /(\d+)/;
    my $school = School->new( school_id => $school_id, %params );
    warn "$$ at ", scalar( localtime ), "\n";
    $school->html();
    return Apache2::Const::OK;
}

1;
