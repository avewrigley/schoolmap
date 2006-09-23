#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;
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
my @opts = qw( silent pidfile! isi ofsted dfes verbose all );
$opts{pidfile} = 1;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}

open( STDERR, ">$Bin/logs/update.log" ) unless $opts{verbose};
print STDERR "$0 ($$) at ", scalar( localtime ), "\n";
my $geo = Geo::Multimap->new();
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );

update_isi() if $opts{isi} || $opts{all};
update_dfes() if $opts{dfes} || $opts{all};
update_ofsted() if $opts{ofsted} || $opts{all};

warn "$0 ($$) finished\n";

my %links;

sub get_text_nodes
{
    my $url = shift;
    my $html = get( $url );
    die "get $url failed" unless $html;
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
    my $html = get( $url );
    die "get $url failed" unless $html;
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
    $links{$url}{$re} = [ keys %l ];
    return @{$links{$url}{$re}};
}

sub update_ofsted
{
    warn "update ofsted ...\n";
    my %result;
    my $base = 'http://www.ofsted.gov.uk/reports/';
    my @fields = qw( 
        school_id 
        postcode 
        name 
        url 
        lea_id 
        type 
        region_id 
        address 
        lat 
        lon 
    );

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
                    SCHOOL: for my $school ( get_links( $type, $re{school} ) )
                    {
                        my $row;
                        my ( $school_id ) = $school =~ $re{school};
                        my %row;
                        $row{school_id} = $school_id;
                        $row{school} = $school;
                        $row{region_id} = $region_id;
                        $row{lea_id} = $lea_id;
                        $row{type} = $type_id;
                        $row{url} = $school;
                        eval {
                            for ( get_text_nodes( $school, _tag => "div", class => "pageIntro" ) )
                            {
                                if ( /How to find (.*)/i )
                                {
                                    $row{name} = $1;
                                }
                                elsif ( /(.* ([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+))/msi )
                                {
                                    @row{qw(address postcode)} = ( $1, $2 );
                                    @row{qw(lat lon)} = $geo->coords( $row{postcode} );
                                }
                            }
                            for ( qw( lat lon name address postcode ) )
                            {
                                die "no $_" unless $row{$_};
                            }
                        };
                        if ( $@ )
                        {
                            warn "FAILED: $row{url} failed: $@\n";
                        }
                        else
                        {
                            warn "SUCCESS: $row{name} ($row{school_id})\n";
                            $sth->execute( @row{@fields} );
                        }
                        $result{$row{url}} = $@;
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
    warn "SUCCESSFUL: ", scalar( grep { ! defined $result{$_} } keys %result ), "\n";
    warn "FAILED: ", scalar( grep { defined $result{$_} } keys %result ), "\n";
    warn "update ofsted finished\n";
}

sub update_isi
{
    warn "update isi ...\n";
    my $base = 'http://www.isinspect.org.uk/isindex/alpha.htm';
    my $re = qr{http://www.isinspect.org.uk/report/\d+.htm};
    my %result;
    for my $school_link ( get_links( $base, $re ) )
    {
        my ( $name, %school );
        eval {
            my $html = get( $school_link );
            $html =~ s/\s*<BR>\s*/\000/g;
            ( $name ) = $html =~ m{<big>(.*?)</big>};
            die "no name" unless $name;
            $name =~ s/^\s*//;
            $name =~ s/\s*$//;
            %school = ( name => $name );
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
            @keys = ( @keys, 'lon', 'lat', 'name' );
            die "no postcode" unless $school{postcode};
            ( $school{lat}, $school{lon} ) = $geo->coords( $school{postcode} );
            my $keys = join( ",", @keys );
            my $placeholders = join( ",", map "?", @keys );
            my $sql = " REPLACE INTO isi ( $keys ) VALUES ( $placeholders )";
            my $sth = $dbh->prepare( $sql );
            $sth->execute( @school{@keys} );
        };
        if ( $@ )
        {
            warn "FAILED: ", ( $name || $school_link ), ": $@\n";
        }
        else
        {
            warn "SUCCESS: $school{name}\n";
        }
        $result{$school_link} = $@;
    }
    warn "SUCCESSFUL: ", scalar( grep { ! defined $result{$_} } keys %result ), "\n";
    warn "FAILED: ", scalar( grep { defined $result{$_} } keys %result ), "\n";
}

sub update_dfes
{
    warn "update dfes ...\n";
    my %result;
    my @primary_keys = qw( name postcode );
    my @generic_keys = qw( address lat lon region lea );
    my %keys = (
        '16to18' => [ qw( 
        url_16to18 
        pupils_16to18 
        average_16to18
        average_16to18pe 
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
        '16to18' => [0,2,3],
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
        '16to18' => "http://www.dfes.gov.uk/performancetables/16to18_05.shtml",
    );
    for my $type qw( secondary 16to18 primary )
    {
        my $type_link = $type_link{$type};
        my @keys = @{$keys{$type}};
        my $sql = 
            "INSERT INTO dfes (" . join( ",", @primary_keys,@generic_keys,@keys ) . ") " .
            "VALUES (" . join( ",", map "?", @primary_keys,@generic_keys,@keys ) . ")" .
            " ON DUPLICATE KEY UPDATE " . join( ",", map "$_=?", @keys )
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
                    for my $t (@$tables) 
                    {
                        ROW: for my $r (@{$t->{rows}}) 
                        {
                            my @cells = map $_->{data}, @{$r->{cells}};
                            my %values = (
                                region => $region,
                                lea => $lea,
                            );
                            next ROW unless my $name_cell = shift @cells;
                            next ROW unless ( $values{url}, $values{name} ) = $name_cell =~ /href=\"([^"]+)"[^>]+title=\"([^"]+)"/;
                            my $abs_url = URI->new_abs( $values{url}, $lea_link );
                            $abs_url =~ s/\&amp;/&/g;
                            my $school_html = get( $abs_url );
                            warn "FAILED: get $values{url} failed\n" and next ROW unless $html;
                            my @indexes = @{$indexes{$type}};
                            my @data = @cells[@indexes];
                            for ( @data )
                            {
                                next ROW unless defined $_ && /^[\d.]+\%?$/;
                                s/%$//;
                            }
                            eval {
                                ( $values{address} ) = $school_html =~ m{
                                    <h3>[^<]+</h3>
                                    (.*?)
                                    (?:<p>|<br\s*/><br\s*/>)
                                }six;
                                die "no address" unless $values{address};
                                $values{address} =~ s/^\s*//;
                                $values{address} =~ s/\s*$//;
                                my @address = split( /\s*<br\s*\/>\s*/, $values{address} );
                                for ( @address )
                                {
                                    $values{postcode} = $1 if /([A-Z]+[0-9][0-9A-Z]*\s+[0-9][A-Z0-9]+)/msi;
                                }
                                $values{address} = join( ", ", @address );
                                die "no postcode" unless $values{postcode};
                                ( $values{lat}, $values{lon} ) = $geo->coords( $values{postcode} );
                                my @args = ( @values{@primary_keys}, @values{@generic_keys}, $abs_url, @data, $abs_url, @data );
                                $sth->execute( @args );
                            };
                            if ( $@ )
                            {
                                warn "FAILED: $abs_url: $@\n";
                            }
                            else
                            {
                                warn "SUCCESS: $values{name}\n";
                            }
                            $result{$abs_url} = $@;
                        }
                    }
                }
            }
        }
    }
    warn "SUCCESSFUL: ", scalar( grep { ! defined $result{$_} } keys %result ), "\n";
    warn "FAILED: ", scalar( grep { defined $result{$_} } keys %result ), "\n";
    warn "update dfes finished\n";
}

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

