#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;
use Parallel::ForkManager;
use File::Slurp;
require URI;
require DBI;
use FindBin qw( $Bin );
use lib "$Bin/lib";
require HTML::TableContentParser;
require HTML::TableParser;
use Pod::Usage;
use Getopt::Long;
require Geo::Multimap;
use LWP::Simple;
require HTML::TreeBuilder;
require HTML::LinkExtractor;
require Proc::Pidfile;
use File::Temp qw/ tempfile /;
use Data::Dumper;

my %opts;
my %update;
my @sources = qw( isi ofsted dfes );
my @opts = qw( source=s silent pidfile! verbose all );
my %links;
my $geo;
my $dbh;

sub get_text_nodes
{
    my $html = shift;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse( $html );
    my $node = $tree->elementify();
    my @tnodes;
    my @nodes = $node->look_down( @_ );
    for my $n ( @nodes )
    {
        () = $n->look_down(
            sub {
                my $element = shift;
                push( 
                    @tnodes, 
                    grep { ! ref( $_ ) && $_ =~ /\S/ } $element->content_list 
                );
            }
        );
    }
    $tree->destroy();
    return @tnodes;
}

sub get_links
{
    my $url = shift;
    my $re = shift;
    my $lx = new HTML::LinkExtractor();
    warn "get $url\n";
    my $html = get( $url );
    warn "get $url failed" and return () unless $html;
    return @{$links{$url}{$re}} if $links{$url}{$re};
    $lx->parse( \$html );
    my %l = 
        map { $_ => 1 }
        map { URI->new_abs( $_, $url ) }
        grep /$re/,
        map { $_->{href} }
        grep { $_->{href} }
        @{$lx->links}
    ;
    $links{$url}{$re} = [ sort keys %l ];
    return @{$links{$url}{$re}};
}

sub create_school
{
    my $name = shift;
    my $postcode = shift;
    my $type = shift;
    die "no name" unless $name;
    die "no postcode" unless $postcode;
    my ( $lat, $lon ) = $geo->coords( $postcode );
    die "no lat / lon for postcode $postcode" unless $lat && $lon;
    my $select_sth = $dbh->prepare( <<SQL );
SELECT school_id FROM school WHERE name = ? AND postcode = ?
SQL
    $select_sth->execute( $name, $postcode );
    my ( $school_id ) = $select_sth->fetchrow;
    return $school_id if defined $school_id;
    my $insert_sth = $dbh->prepare( <<SQL );
INSERT INTO school ( name, postcode, lat, lon, type ) VALUES ( ?,?,?,?,? )
SQL
    $insert_sth->execute( $name, $postcode, $lat, $lon, $type );
    $insert_sth->finish();
    $select_sth->execute( $name, $postcode );
    ( $school_id ) = $select_sth->fetchrow;
    $select_sth->finish();
    return $school_id;
}

{
    my %modtime;
    my %result;

    sub set_modtime
    {
        my $url = shift;
        my $modtime = $modtime{$url};
        return unless $modtime;
        my $sql = "REPLACE INTO url ( url, modtime ) VALUES ( ?, ? )";
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $url, $modtime );
        $sth->finish;
    }

    sub get_modtime
    {
        my $url = shift;
        my $sql = "SELECT modtime FROM url WHERE url = ?";
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $url );
        my ( $modtime) = $sth->fetchrow;
        $sth->finish;
        return $modtime;
    }

    sub no_update
    {
        my $url = shift;
        $result{$url} = undef;
        my $db_modtime = get_modtime( $url );
        my $http_modtime = $modtime{$url} = ( head( $url ) )[2];
        return if not defined $http_modtime;
        return if not defined $db_modtime;
        if ( $db_modtime == $http_modtime )
        {
            warn "$url not changed ($db_modtime)\n";
            return 1;
        }
        return;
    }

    sub update_report
    {
        my $error = shift;
        my $url = shift;
        my $name = shift;
        my $description = $name ? "$name ($url)" : $url;
        if ( $error )
        {
            warn "FAILED: $description: $error\n";
            $result{$url} = $error;
        }
        else
        {
            warn "SUCCESS: $description\n";
            set_modtime( $url );
        }
    }

    sub print_report
    {
        warn "SUCCESSFUL: ", scalar( grep { ! defined $result{$_} } keys %result ), "\n";
        warn "FAILED: ", scalar( grep { defined $result{$_} } keys %result ), "\n";
    }
}

$update{ofsted} = sub {
    warn "update ofsted ...\n";
    my %result;
    my $base = 'http://www.ofsted.gov.uk/reports/';
    my @fields = qw( ofsted_school_id school_id ofsted_url lea_id region_id address );

    my $fields = join( ",", @fields );
    my @placeholders = map "?", @fields;
    my $placeholders = join( ",", @placeholders );
    my $sth = $dbh->prepare( <<SQL );
REPLACE INTO ofsted ( $fields ) VALUES ( $placeholders )
SQL

    my %re = (
        region => qr/fuseaction=leaByRegion&id=(\d+)/,
        lea => qr/fuseaction=lea&id=(\d+)/,
        type => qr/fuseaction=listByLea&lea=\d+&type=(.*)/,
        school => qr/fuseaction=summary&id=(\d+)/,
        page => qr/page=(\d+)/,
    );
    for my $region ( get_links( $base, $re{region} ) )
    {
        my ( $region_id ) = $region =~ $re{region};
        for my $lea ( get_links( $region, $re{lea} ) )
        {
            my ( $lea_id ) = $lea =~ $re{lea};
            for my $type ( get_links( $lea, $re{type} ) )
            {
                my ( $type_id ) = $type =~ $re{type};
                my $page_no = 1;
                while ( defined $page_no )
                {
                    SCHOOL: for my $school_url ( get_links( $type, $re{school} ) )
                    {
                        my ( $name, $postcode );
                        my ( $school_id ) = $school_url =~ $re{school};
                        my %school;
                        $school{ofsted_school_id} = $school_id;
                        $school{region_id} = $region_id;
                        $school{lea_id} = $lea_id;
                        $school{ofsted_url} = $school_url;
                        eval {
                            my $html = get( $school_url );
                            die "Can't get $school_url\n" unless $html;
                            for ( get_text_nodes( $html, _tag => "div", class => "pageIntro" ) )
                            {
                                if ( /How to find (.*)/i )
                                {
                                    $name = $1;
                                }
                                elsif ( /(.* ([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+))/msi )
                                {
                                    $school{address} = $1;
                                    $postcode = $2;
                                }
                            }
                            $school{school_id} = create_school( $name, $postcode, $type_id );
                            die "no school_id" unless $school_id;
                            die "no address" unless $school{address};
                            $sth->execute( @school{@fields} );
                        };
                        update_report( $@, $school_url, $name );
                    }
                    my @pages = get_links( $type, $re{page} );
                    my $next;
                    for my $page ( @pages )
                    {
                        my ( $no ) = $page =~ $re{page};
                        if ( $no == $page_no+1 )
                        {
                            $next = $no;
                            $type = $page;
                        }
                    }
                    $page_no = $next;
                }
            }
        }
    }
    print_report();
};

$update{isi} = sub {
    warn "update isi ...\n";
    my $base = 'http://www.isinspect.org.uk/isindex/alpha.htm';
    my $re = qr{http://www.isinspect.org.uk/report/\d+.htm};
    for my $school_url ( get_links( $base, $re ) )
    {
        my ( $name, %school );
        next if no_update( $school_url );
        eval {
            my $html = get( $school_url );
            die "can't get $school_url" unless $html;
            $html =~ s/\s*<BR>\s*/\000/g;
            ( $name ) = $html =~ m{<big>(.*?)</big>};
            die "no name" unless $name;
            $name =~ s/^\s*//;
            $name =~ s/\s*$//;
            %school = ( isi_url => $school_url );
            my ( @keys, @vals );
            my $tp = HTML::TableParser->new(
                [
                    {
                        id => '1.1.2.1',
                        hdr => sub { 
                            @keys = map { s![\s/]+!_!g; $_ } map lc( $_ ), map { split( "\000", $_ ) } @{$_[2]};
                        },
                        row => sub { @school{@keys} = @vals = map { split( "\000", $_ ) } @{$_[2]} },
                    },
                ],
                {
                    Decode => 1,
                    DecodeNBSP => 1,
                    Chomp => 1,
                    Trim => 1,
                }
            );
            $tp->parse( $html );
            my $postcode = delete $school{postcode};
            $school{school_id} = create_school( $name, $postcode, "independent" );
            my $keys = join( ",", keys %school );
            my $placeholders = join( ",", map "?", keys %school );
            my $sql = " REPLACE INTO isi ( $keys ) VALUES ( $placeholders )";
            my $sth = $dbh->prepare( $sql );
            $sth->execute( values %school );
        };
        update_report( $@, $school_url, $name );
    }
    print_report();
};

$update{dfes} = sub {
    warn "update dfes ...\n";
    my %result;
    my @generic_keys = qw( school_id dfes_url address region lea );
    my %keys = (
        post16 => [ qw( 
            url_post16 
            pupils_post16 
            average_post16 
            average_post16pe
        ) ],
        primary => [ qw(
            url_primary
            pupils_primary
            smi
            eng_l4
            eng_l5
            math_l4
            math_l5
            sci_l4
            sci_l5
            average_primary
        ) ],
        secondary => [ qw(
            url_secondary
            pupils_secondary
            gcse_l2
            gcse_l1
            average_secondary
        ) ]
    );
    my %indexes = (
        post16 => [0,2,3],
        primary => [0,1,6,7,9,10,12,13,15],
        secondary => [0,7,8,10],
    );
    my $base = 'http://www.dfes.gov.uk/performancetables/';
    my %re = (
        regions => qr{/performancetables/.*/(?:regions|lscs).shtml},
        region => qr{/performancetables/.*/(?:region|lsc)(\d+).shtml},
        lea => qr{/performancetables/.*\?Mode=Z&No=(\d+)},
    );

    my %type_link = (
        primary => "http://www.dfes.gov.uk/performancetables/primary_05.shtml",
        secondary => "http://www.dfes.gov.uk/performancetables/schools_05.shtml",
        post16 => "http://www.dfes.gov.uk/performancetables/16to18_05.shtml",
    );
    for my $type qw( post16 secondary primary )
    {
        my $type_link = $type_link{$type};
        my @keys = @{$keys{$type}};
        my $sql = 
            "REPLACE INTO dfes (" . join( ",", @generic_keys,@keys ) . ") " .
            "VALUES (" . join( ",", map "?", @generic_keys,@keys ) . ")"
        ;
        my $sth = $dbh->prepare( $sql );
        my $tcp = HTML::TableContentParser->new();
        for my $regions_link ( get_links( $type_link, $re{regions} ) )
        {
            for my $region_link ( get_links( $regions_link, $re{region} ) )
            {
                my ( $region ) = $region_link =~ $re{region};
                for my $lea_link ( get_links( $region_link, $re{lea} ) )
                {
                    my ( $lea ) = $lea_link =~ $re{lea};
                    my $html = get( $lea_link );
                    warn "get $lea_link failed" and next unless $html;
                    my $tables = $tcp->parse($html);
                    for my $t ( @$tables ) 
                    {
                        ROW: for my $r (@{$t->{rows}}) 
                        {
                            my @cells = map $_->{data}, @{$r->{cells}};
                            my %school = (
                                region => $region,
                                lea => $lea,
                            );
                            next ROW unless my $name_cell = shift @cells;
                            my ( $url, $name, $postcode );
                            next ROW unless ( $url, $name ) = $name_cell =~ /href=\"([^"]+)"[^>]+title=\"([^"]+)"/;
                            my $school_url = URI->new_abs( $url, $lea_link );
                            $school_url =~ s/\&amp;/&/g;
                            my @indexes = @{$indexes{$type}};
                            my @data = @cells[@indexes];
                            for ( @data )
                            {
                                next ROW unless defined $_ && /^[\d.]+\%?$/;
                                s/%$//;
                            }
                            next ROW if no_update( $school_url );
                            eval {
                                my $school_html = get( $school_url );
                                die "get $school_url failed\n" unless $school_html;
                                $school{dfes_url} = $school_url;
                                ( $school{address} ) = $school_html =~ m{
                                    <h3>[^<]+</h3>
                                    (.*?)
                                    (?:<p>|<br\s*/><br\s*/>)
                                }six;
                                die "no address" unless $school{address};
                                $school{address} =~ s/^\s*//;
                                $school{address} =~ s/\s*$//;
                                my @address = split( /\s*<br\s*\/>\s*/, $school{address} );
                                for ( @address )
                                {
                                    $postcode = $1 if /([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+)/msi;
                                }
                                $school{school_id} = create_school( $name, $postcode, $type );
                                $school{address} = join( ", ", @address );
                                my @args = ( @school{@generic_keys}, $school_url, @data );
                                $sth->execute( @args );
                            };
                            update_report( $@, $school_url, $name );
                        }
                    }
                }
            }
        }
    }
    print_report();
    warn "update dfes finished\n";
};

# Main

$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}

open( STDERR, ">$Bin/logs/update.log" ) unless $opts{verbose};
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";

if ( $opts{all} )
{
    my $pm = Parallel::ForkManager->new( scalar( @sources ) );
    $pm->run_on_start( sub { warn "start process: @_\n" } );
    $pm->run_on_finish( sub { warn "finish process: @_\n" } );
    for my $source ( @sources )
    {
        my $pid = $pm->start( $source );
        if ( $pid )
        {
            warn "child process $pid forked for $source\n";
            next;
        }
        my $logfile = "$Bin/logs/update.$source.log";
        warn "open logfile $logfile\n";
        open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
        print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
        $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
        $geo = Geo::Multimap->new();
        $update{$source}->();
        $pm->finish;
    }
    warn "Wait for children to finish ...\n";
    $pm->wait_all_children();
    warn "all done\n";
}
if ( $opts{source} )
{
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $geo = Geo::Multimap->new();
    warn "update $opts{source}\n";
    die "no update code for $opts{source} ($update{$opts{source}})\n" unless ref( $update{$opts{source}} ) eq 'CODE';
    $update{$opts{source}}->();
}

warn "$0 ($$) finished\n";

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

