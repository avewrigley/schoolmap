#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;
use Carp;
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
my @opts = qw( flush year=s type=s force source=s silent pidfile! verbose );
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
    my $html = shift;
    my $url = shift;
    return () unless $html;
    my $re = shift;
    my $lx = new HTML::LinkExtractor();
    $lx->parse( \$html );
    my @links = @{$lx->links};
    my @hrefs = map { $_->{href} } grep { $_->{href} } @links;
    my @fhrefs = grep /$re/, @hrefs;
    my @afhrefs = map { URI->new_abs( $_, $url ) } @fhrefs;
    warn "no links match $re on $url\n" unless @afhrefs;
    return @afhrefs;
}

sub get_html
{
    my $url = shift;
    warn "get $url\n";
    my $html = get( $url ) || warn "get $url failed";
    return ( $html, $url );
}

sub create_school
{
    my $name = shift;
    my $postcode = shift;
    my $address = shift;
    die "no name" unless $name;
    die "no postcode" unless $postcode;
    my ( $lat, $lon ) = $geo->coords( $postcode );
    die "no lat / lon for postcode $postcode" unless $lat && $lon;
    my $select_sth = $dbh->prepare( <<SQL );
SELECT school_id FROM school WHERE name = ? AND postcode = ?
SQL
    my $school_id;
    unless ( $opts{force} )
    {
        $select_sth->execute( $name, $postcode );
        ( $school_id ) = $select_sth->fetchrow;
        return $school_id if defined $school_id;
    }
    my $replace_sth = $dbh->prepare( <<SQL );
REPLACE INTO school ( name, postcode, lat, lon, address ) VALUES ( ?,?,?,?,? )
SQL
    $replace_sth->execute( $name, $postcode, $lat, $lon, $address );
    $replace_sth->finish();
    $select_sth->execute( $name, $postcode );
    ( $school_id ) = $select_sth->fetchrow;
    $select_sth->finish();
    return $school_id;
}

sub add_school_type
{
    my $school_id = shift;
    my $type = shift;
    my $insert_sth = $dbh->prepare( <<SQL );
INSERT IGNORE INTO school_type ( school_id, type ) VALUES ( ?,? )
SQL
    $insert_sth->execute( $school_id, $type );
    $insert_sth->finish();
}

{
    my %result;

    sub init_report
    {
        %result = ();
    }

    sub set_modtime
    {
        my $url = shift;
        my $modtime = ( head( $url ) )[2];
        warn "no modtime for $url\n" and return unless $modtime;
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
        my $http_modtime = ( head( $url ) )[2];
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
        }
        else
        {
            warn "SUCCESS: $description\n";
            set_modtime( $url );
        }
        $result{$url} = $error;
    }

    sub print_report
    {
        warn "SUCCESSFUL: ", scalar( grep { ! $result{$_} } keys %result ), "\n";
        warn "FAILED: ", scalar( grep { $result{$_} } keys %result ), "\n";
    }
}

$update{ofsted} = sub {
    warn "update ofsted ...\n";
    init_report();
    my $base = 'http://www.ofsted.gov.uk/reports/';
    my @fields = qw( ofsted_school_id school_id ofsted_url lea_id region_id );

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
    for my $region ( get_links( get_html( $base ), $re{region} ) )
    {
        my ( $region_id ) = $region =~ $re{region};
        for my $lea ( get_links( get_html( $region ), $re{lea} ) )
        {
            my ( $lea_id ) = $lea =~ $re{lea};
            for my $type ( get_links( get_html( $lea ), $re{type} ) )
            {
                my ( $type_id ) = $type =~ $re{type};
                next if $type_id eq 'independent';
                my $page_no = 1;
                while ( defined $page_no )
                {
                    SCHOOL: for my $school_url ( get_links( get_html( $type ), $re{school} ) )
                    {
                        my ( $html ) = get_html( $school_url );
                        warn "can't get $school_url\n" and next SCHOOL unless $html;
                        my ( $report_url ) = get_links( $html, $school_url, qr{/reports/.*\.(html?|pdf)$}, 1 );
                        unless ( $report_url )
                        {
                            update_report( "can't find report", $school_url );
                            next;
                        }
                        warn "report_url: $report_url\n";
                        next SCHOOL if no_update( $report_url );
                        my ( $name, $postcode );
                        my ( $school_id ) = $school_url =~ $re{school};
                        my %school;
                        $school{ofsted_school_id} = $school_id;
                        $school{region_id} = $region_id;
                        $school{lea_id} = $lea_id;
                        $school{ofsted_url} = $report_url;
                        eval {
                            my $address;
                            for ( get_text_nodes( $html, _tag => "div", class => "pageIntro" ) )
                            {
                                if ( /How to find (.*)/i )
                                {
                                    $name = $1;
                                }
                                elsif ( /(.*) ([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+)/msi )
                                {
                                    $address = $1;
                                    $postcode = $2;
                                }
                            }
                            die "no address" unless $address;
                            $school{school_id} = create_school( $name, $postcode, $address );
                            add_school_type( $school{school_id}, $type_id );
                            die "no school_id" unless $school_id;
                            $sth->execute( @school{@fields} );
                        };
                        update_report( $@, $school_url, $name );
                    }
                    my @pages = get_links( get_html( $type ), $re{page} );
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
    init_report();
    my $base = 'http://www.isinspect.org.uk/isindex/alpha.htm';
    my $re = qr{http://www.isinspect.org.uk/report/\d+.htm};
    for my $school_url ( get_links( get_html( $base ), $re ) )
    {
        my ( $name, %school, $report_url );
        my ( $html ) = get_html( $school_url );
        warn "can't get $school_url" and next unless $html;
        ( $report_url ) = get_links( $html, $school_url, qr{http://www.isinspect.org.uk/reports/\d{4}/[\d_]+.htm} );
        warn "no report URL on $school_url\n" and next unless $report_url;
        next if no_update( $report_url );
        eval {
            $html =~ s/\s*<BR>\s*/\000/g;
            ( $name ) = $html =~ m{<big>(.*?)</big>};
            die "no name" unless $name;
            $name =~ s/^\s*//;
            $name =~ s/\s*$//;
            %school = ( isi_url => $report_url );
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
            my $address;
            my ( $current_info ) = get_links( $html, $school_url, qr{http://www.isc.co.uk/index.php/\d+/\d+} );
            if ( $current_info )
            {
                warn "current info url: $current_info\n";
                my ( $cihtml ) = get_html( $current_info );
                die "Can't get current info URL $current_info\n" unless $cihtml;
                my ( $addr_str ) = $cihtml =~ m{<td class="schoolcontent">(.*?)</td>}si;
                my @address = split( /\s*<br>\s*/, $addr_str );
                s{<[^>]+>}{}g for @address;
                @address = grep !/$postcode/i, @address;
                if ( @address )
                {
                    $address = join( ", ", @address );
                    warn "address: $address\n";
                }
                else
                {
                    warn "no address\n";
                }

            }
            $school{school_id} = create_school( $name, $postcode, $address );
            add_school_type( $school{school_id}, "independent" );
            my $keys = join( ",", keys %school );
            my $placeholders = join( ",", map "?", keys %school );
            my $sql = " REPLACE INTO isi ( $keys ) VALUES ( $placeholders )";
            my $sth = $dbh->prepare( $sql );
            $sth->execute( values %school );
        };
        update_report( $@, $report_url, $name );
    }
    print_report();
};

$update{dfes} = sub {
    warn "update dfes ...\n";
    init_report();
    my @generic_keys = qw( region lea );
    my %keys = (
        post16 => [ qw(
            pupils_post16 
            average_post16 
            post16_url
        ) ],
        ks3 => [ qw(
            pupils_ks3 
            average_ks3 
            ks3_url
        ) ],
        primary => [ qw(
            pupils_primary
            average_primary
            primary_url
        ) ],
        secondary => [ qw(
            pupils_secondary
            average_secondary
            secondary_url
        ) ]
    );
    my %indexes = (
        post16 => [0,2],
        primary => [0,15],
        ks3 => [0,11],
        secondary => [0,10],
    );
    my %types = (
        post16 => "post16",
        primary => "primary",
        ks3 => "secondary",
        secondary => "secondary",
    );
    my $base = 'http://www.dfes.gov.uk/performancetables/';
    my %re = (
        regions => qr{/performancetables/.*/(?:regions|lscs).shtml},
        region => qr{/performancetables/.*/(?:region|lsc)(\d+).shtml},
        lea => qr{/performancetables/.*\?Mode=Z&No(?:Lea)?=(\d+)},
    );
    my $year = $1 if $opts{year} =~ /(\d\d)$/;
    my %type_link = (
        primary => "http://www.dfes.gov.uk/performancetables/primary_$year.shtml",
        secondary => "http://www.dfes.gov.uk/performancetables/schools_$year.shtml",
        post16 => "http://www.dfes.gov.uk/performancetables/16to18_$year.shtml",
        ks3 => "http://www.dfes.gov.uk/performancetables/ks3_$year.shtml",
    );
    my @types = keys %keys;
    if ( $opts{type} )
    {
        die "$opts{type} is not a valid type (", join( ",", keys %keys ), ")\n" unless $keys{$opts{type}};
        @types = ( $opts{type} );
    }
    for my $type ( @types )
    {
        my $type_link = $type_link{$type};
        my @keys = ( @generic_keys, @{$keys{$type}} );
        my $select_sth = $dbh->prepare( <<SQL );
SELECT school_id FROM dfes WHERE school_id = ? AND year = ?
SQL
        my $update_sql = 
            "UPDATE dfes SET " . 
            join( ",", map( "$_ = ?", @keys ) ) .
            " WHERE school_id = ? AND year = ?"
        ;
        my $update_sth = $dbh->prepare( $update_sql );
        my $insert_sql = 
            "INSERT INTO dfes (" . 
            join( ",", 'school_id', 'year', @keys ) . ") " .
            "VALUES (" . join( ",", map "?", 'school_id', 'year', @keys ) . ")"
        ;
        my $insert_sth = $dbh->prepare( $insert_sql );
        my $tcp = HTML::TableContentParser->new();
        for my $regions_link ( get_links( get_html( $type_link ), $re{regions} ) )
        {
            for my $region_link ( get_links( get_html( $regions_link ), $re{region} ) )
            {
                my ( $region ) = $region_link =~ $re{region};
                for my $lea_link ( get_links( get_html( $region_link ), $re{lea} ) )
                {
                    warn "LEA: $lea_link\n";
                    my ( $lea ) = $lea_link =~ $re{lea};
                    my ( $html ) = get_html( $lea_link );
                    warn "get $lea_link failed" and next unless $html;
                    my $tables = $tcp->parse( $html );
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
                            warn "name: $name\n";
                            my $school_url = URI->new_abs( $url, $lea_link );
                            $school_url =~ s/\&amp;/&/g;
                            my @indexes = @{$indexes{$type}};
                            my @data = @cells[@indexes];
                            warn "data: @data\n";
                            for ( @data )
                            {
                                next ROW unless defined $_ && /^[\d.]+\%?$/;
                                s/%$//;
                            }
                            next ROW if no_update( $school_url );
                            eval {
                                my ( $school_html ) = get_html( $school_url );
                                my $address;
                                die "get $school_url failed\n" unless $school_html;
                                ( $address ) = $school_html =~ m{
                                    <h3>[^<]+</h3>
                                    (.*?)
                                    (?:<p>|<br\s*/><br\s*/>)
                                }six;
                                die "no address" unless $address;
                                $address =~ s/^\s*//;
                                $address =~ s/\s*$//;
                                my @a = split( /\s*<br\s*\/>\s*/, $address );
                                my @address;
                                for ( @a )
                                {
                                    if ( /([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+)/msi )
                                    {
                                        $postcode = $1;
                                    }
                                    else
                                    {
                                        push( @address, $_ );
                                    }
                                }
                                $address = join( ", ", @address );
                                $school{school_id} = create_school( $name, $postcode, $address );
                                add_school_type( $school{school_id}, $types{$type} );
                                $select_sth->execute( $school{school_id}, $opts{year} );
                                if ( $select_sth->fetchrow )
                                {
                                    warn "$school{school_id},$opts{year} already exists\n";
                                    $update_sth->execute( 
                                        @school{@generic_keys}, 
                                        @data, 
                                        $school_url,
                                        $school{school_id},
                                        $opts{year},
                                    );
                                }
                                else
                                {
                                    warn "$school{school_id},$opts{year} is new\n";
                                    $insert_sth->execute( 
                                        $school{school_id},
                                        $opts{year},
                                        @school{@generic_keys}, 
                                        @data,
                                        $school_url,
                                    );
                                }
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
$opts{year} = 2005;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
die "year $opts{year} is not valid\n" unless $opts{year} =~ /^\w{4}$/;
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}

if ( $opts{flush} )
{
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    for my $table ( qw( dfes ofsted isi school school_type url ) )
    {
        warn "flush $table\n";
        $dbh->do( "DELETE FROM $table" );
    }
    $dbh->disconnect();
    exit;
}

if ( $opts{source} )
{
    my $logfile = "$Bin/logs/update.$opts{source}.log";
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n" unless $opts{verbose};
    print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
    $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $geo = Geo::Multimap->new();
    warn "update $opts{source}\n";
    die "no update code for $opts{source} ($update{$opts{source}})\n" unless ref( $update{$opts{source}} ) eq 'CODE';
    $update{$opts{source}}->();
    $dbh->disconnect();
}
else
{
    open( STDERR, ">$Bin/logs/update.log" ) unless $opts{verbose};
    print STDERR "$0 ($$) at ", scalar( localtime ), "\n";

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
        open( STDERR, ">$logfile" ) or die "can't write to $logfile\n" unless $opts{verbose};
        print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
        $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
        $geo = Geo::Multimap->new();
        $update{$source}->();
        $dbh->disconnect();
        $pm->finish;
    }
    warn "Wait for children to finish ...\n";
    $pm->wait_all_children();
    warn "all done\n";
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

