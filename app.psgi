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

my $config_file = "$Bin/config/schoolmap.yaml";
my $template_dir = "$Bin/templates";

sub get_schools_page
{
    my $schools = shift;
    my $parameters = shift;

    my $config = LoadFile( "$Bin/config/google.yaml" );
    print "Content-Type: text/html\n\n";
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
    my $schools = Schools->new( config_file => $config_file, template_dir => $template_dir, parameters => $parameters );
    my $content = '';
    if ( $path eq "/" || $path eq "/index.cgi" )
    {
        my $body = get_schools_page( $schools, $parameters );
        $content = "<body>$body</body>";
    }
    elsif ( $path eq '/schools' )
    {
        my %parameters = ( format => "json", %$parameters );
        ( $content, $content_type ) = $schools->render_as( $parameters{format} );
    }
    else
    {
        my $file_path = "$Bin/docroot$path";
        my $mm = new File::MMagic;
        $content_type = $mm->checktype_filename( $file_path );
        $content = read_file( $file_path );
    }
    # open( STDERR, ">>$Bin/logs/index.log" );
    my $res = $req->new_response( $code );
    $res->content_type( $content_type );
    $res->body( $content );
    return $res->finalize;
}
