#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use lib qw( t/lib );

use Test::More 'no_plan';
use JSON;

# application loads
BEGIN { use_ok "Test::WWW::Mechanize::Catalyst" => "TestApp" }
my $mech = Test::WWW::Mechanize::Catalyst->new;

# get metadata for the album table
$mech->get_ok( '/album/dumpmeta', 'Get album listframework metadata' );
is( $mech->ct, 'application/json', 'Metadata content type' );

my $response = JSON::from_json( $mech->content );

#use Data::Dumper;
#print STDERR Dumper $response;

my $expected = {
    'table_info' => {
        'LFB::DBIC::SleeveNotes' => {
            'pk'        => 'id',
            'moniker'   => 'SleeveNotes',
            'col_order' => [ 'id', 'text', 'album_id' ],
            'table'     => 'sleeve_notes',
            'path'      => 'sleevenotes',
            'title'     => 'Sleeve Notes',
            'cols'      => {
                'album_id' => {
                    'required'    => 1,
                    'extjs_xtype' => 'numberfield',
                    'fk_model'    => 'LFB::DBIC::Album',
                    'editable'    => 0,
                    'heading'     => 'Album',
                    'is_fk'       => 1
                },
                'text' => {
                    'required' => 1,
                    'editable' => 1,
                    'heading'  => 'Text'
                },
                'id' => {
                    'required'    => 1,
                    'extjs_xtype' => 'numberfield',
                    'editable'    => 0,
                    'heading'     => 'Id'
                }
            }
        },
        'LFB::DBIC::Artist' => {
            'mfks'    => { 'albums' => 'Albums' },
            'pk'      => 'id',
            'moniker' => 'Artist',
            'col_order' => [ 'id', 'forename', 'surname', 'pseudonym', 'born' ],
            'table' => 'artist',
            'path'  => 'artist',
            'title' => 'Artist',
            'cols'  => {
                'pseudonym' => {
                    'required' => 1,
                    'editable' => 1,
                    'heading'  => 'Pseudonym'
                },
                'forename' => {
                    'required' => 1,
                    'editable' => 1,
                    'heading'  => 'Forename'
                },
                'born' => {
                    'required'    => 1,
                    'extjs_xtype' => 'datefield',
                    'editable'    => 1,
                    'heading'     => 'Born'
                },
                'id' => {
                    'required'    => 1,
                    'extjs_xtype' => 'numberfield',
                    'editable'    => 0,
                    'heading'     => 'Id'
                },
                'surname' => {
                    'required' => 1,
                    'editable' => 1,
                    'heading'  => 'Surname'
                }
            }
        },
        'LFB::DBIC::Album' => {
            'mfks'      => { 'tracks' => 'Tracks' },
            'pk'        => 'id',
            'moniker'   => 'Album',
            'col_order' => [
                'id',        'title', 'recorded', 'deleted',
                'artist_id', 'sleeve_notes'
            ],
            'table' => 'album',
            'path'  => 'album',
            'title' => 'Album',
            'cols'  => {
                'sleeve_notes' => {
                    'editable' => 1,
                    'heading'  => 'Sleeve Notes',
                    'fk_model' => 'LFB::DBIC::SleeveNotes',
                    'is_rr'    => 1
                },
                'artist_id' => {
                    'required'    => 1,
                    'extjs_xtype' => 'numberfield',
                    'fk_model'    => 'LFB::DBIC::Artist',
                    'editable'    => 1,
                    'heading'     => 'Artist',
                    'is_fk'       => 1
                },
                'deleted' => {
                    'required'    => 1,
                    'extjs_xtype' => 'checkbox',
                    'editable'    => 1,
                    'heading'     => 'Deleted'
                },
                'recorded' => {
                    'required'    => 1,
                    'extjs_xtype' => 'datefield',
                    'editable'    => 1,
                    'heading'     => 'Recorded'
                },
                'title' => {
                    'required' => 1,
                    'editable' => 1,
                    'heading'  => 'Title'
                },
                'id' => {
                    'required'    => 1,
                    'extjs_xtype' => 'numberfield',
                    'editable'    => 0,
                    'heading'     => 'Id'
                }
            }
        }
    },
    'model'      => 'LFB::DBIC::Album',
    'table2path' => {
        'Album'        => 'album',
        'Copyright'    => 'copyright',
        'Sleeve Notes' => 'sleevenotes',
        'Track'        => 'track',
        'Artist'       => 'artist'
    },
    'tab_order' => {
        'LFB::DBIC::SleeveNotes' => 3,
        'LFB::DBIC::Artist'      => 2,
        'LFB::DBIC::Album'       => 1
    },
    'main' => {
        'mfks'    => { 'tracks' => 'Tracks' },
        'pk'      => 'id',
        'moniker' => 'Album',
        'col_order' =>
          [ 'id', 'title', 'recorded', 'deleted', 'artist_id', 'sleeve_notes' ],
        'table' => 'album',
        'path'  => 'album',
        'title' => 'Album',
        'cols'  => {
            'sleeve_notes' => {
                'editable' => 1,
                'heading'  => 'Sleeve Notes',
                'fk_model' => 'LFB::DBIC::SleeveNotes',
                'is_rr'    => 1
            },
            'artist_id' => {
                'required'    => 1,
                'extjs_xtype' => 'numberfield',
                'fk_model'    => 'LFB::DBIC::Artist',
                'editable'    => 1,
                'heading'     => 'Artist',
                'is_fk'       => 1
            },
            'deleted' => {
                'required'    => 1,
                'extjs_xtype' => 'checkbox',
                'editable'    => 1,
                'heading'     => 'Deleted'
            },
            'recorded' => {
                'required'    => 1,
                'extjs_xtype' => 'datefield',
                'editable'    => 1,
                'heading'     => 'Recorded'
            },
            'title' => {
                'required' => 1,
                'editable' => 1,
                'heading'  => 'Title'
            },
            'id' => {
                'required'    => 1,
                'extjs_xtype' => 'numberfield',
                'editable'    => 0,
                'heading'     => 'Id'
            }
        }
    }
};

is_deeply( $response, $expected, 'Metadata is as we expect' );

#warn $mech->content;
__END__
