use Plack::Request;
require Template;
use Data::Dumper;
use YAML qw( LoadFile );
use FindBin qw( $Bin );
use File::Slurp;
use File::MMagic;

use lib "$Bin/lib";
require Schools;

use strict;
use warnings;

sub get_schools_page
{
    my $parameters = shift;

    my $config = LoadFile( "$Bin/config/google.yaml" );
    warn "$$ at ", scalar( localtime ), "\n";
    print "Content-Type: text/html\n\n";
    my $schools = Schools->new( %{$parameters} );
    warn "get school phases\n";
    $parameters->{phases} = $schools->get_phases;
    $parameters->{order_bys} = $schools->get_order_bys;
    my $template_file = 'index.tt';
    $parameters->{$_} = $config->{$_} for keys %$config;
    my $template = Template->new( INCLUDE_PATH => "$Bin/templates" );
    my $output = '';
    $template->process( $template_file, $parameters, \$output )
        || die $template->error()
    ;
    return $output;
}

sub {
    my $req = Plack::Request->new( shift );
    my $code = 200;
    my $content_type = "text/html";
    my $path = $req->path_info;
    my $parameters = $req->parameters;
    warn "path = $path\n";
    my $content = '';
    warn Dumper $parameters;
    if ( $path eq "/" || $path eq "/index.cgi" )
    {
        my $body = get_schools_page( $parameters );
        $content = "<body>$body</body>";
    }
    elsif ( $path eq '/schools.cgi' )
    {

        my %parameters = ( format => "json", %$parameters );
        if ( exists $parameters{phases} )
        {
            $content_type = "application/json";
            $content = Schools->new( %parameters )->phases();
        }
        else
        {
            if ( $parameters{format} eq 'json' )
            {
                $content_type = "application/json";
                $content = Schools->new( %parameters )->json();
            }
            else
            {
                $content = Schools->new( %parameters )->xml();
                $content_type = "text/xml";
            }
        }
    }
    else
    {
        my $file_path = "$Bin$path";
        my $mm = new File::MMagic;
        $content_type = $mm->checktype_filename( $file_path );
        warn "content_type = $content_type\n";
        $content = read_file( $file_path );
    }
    # open( STDERR, ">>$Bin/logs/index.log" );
    my $res = $req->new_response( $code );
    $res->content_type( $content_type );
    $res->body( $content );
    return $res->finalize;
}
