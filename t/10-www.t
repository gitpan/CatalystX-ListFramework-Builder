#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use lib qw( t/lib );

use Test::More 'no_plan';

# application loads
BEGIN { use_ok "Test::WWW::Mechanize::Catalyst" => "TestApp" }
my $mech = Test::WWW::Mechanize::Catalyst->new;

# get basic template, no Metadata
$mech->get_ok('/helloworld', 'Get Hello World page');
is($mech->ct, 'text/html', 'Hello World page content type');
$mech->content_contains('Hello, World!', 'Hello World page content');

# basic Metadata processing - tables list
for (qw( /foobar / )) {
    $mech->get_ok($_, "Get tables list page ($_)");
    is($mech->ct, 'text/html', "Tables list page content type ($_)");
    $mech->content_contains(
        q{Please select a table by clicking one of the links below},
        "Tables list page content ($_)"
    );
}

$mech->content_contains(
    qq{<li><a href="http://localhost//$_">} . ucfirst($_) . q{</a></li>},
    "Tables list page contains a link to $_ table"
) for qw( album artist copyright track );

my @links = $mech->find_all_links( url_regex => qr/localhost/ );
$mech->links_ok( [$_], 'Check table link '. $_->url ) for @links;

my $VERSION = $CatalystX::ListFramework::Builder::VERSION;
foreach (qw( album artist copyright track )) {
    $mech->get_ok("/$_", "Get listframework for $_ table");
    $mech->title_is(ucfirst($_) ." List - powered by LFB v$VERSION", "Page title for $_");
    $mech->content_contains('Ext.data.Record.create', "Storage tempate for $_");
    $mech->content_contains('new Ext.Window', "Create/Update form tempate for $_");
    $mech->content_contains('Ext.grid.ColumnModel', "Grid tempate for $_");
}

#warn $mech->content;
__END__
