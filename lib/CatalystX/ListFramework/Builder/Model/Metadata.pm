package CatalystX::ListFramework::Builder::Model::Metadata;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Component';

use List::Util qw(first);
use Scalar::Util qw(weaken);

my %extra_for = (
    datefield => q{,format: 'Y-m-d'},
);

my %xtype_for = (
    boolean => 'checkbox',
);

map {$xtype_for{$_} = 'numberfield'} (
    'bigint',
    'bigserial',
    'decimal',
    'double precision',
    'integer',
    'money',
    'numeric',
    'real',
    'smallint',
    'serial',
);

map {$xtype_for{$_} = 'timefield'} (
    'time',
    'time without time zone',
    'time with time zone',
);

map {$xtype_for{$_} = 'datefield'} (
    'date',
    'timestamp',
    'timestamp without time zone',
    'timestamp with time zone',
);

sub process {
    my ($self, $c, @parts) = @_;
    return if !scalar @parts;

    my $try_moniker = _qualify2package(@parts);
    my $lf = { model => _moniker2model($c, $try_moniker) };
    return if !defined $lf->{model};

    my $source = $c->model($lf->{model})->result_source;
    foreach my $m ($source->schema->sources) {
        $lf->{table2path}->{ _m2title($m) } = _m2path($m);
    }

    _build_table_info($c, $lf, $lf->{model}, 1);

    #use Data::Dumper;
    #die Dumper $lf;

    $c->stash->{lf} = $lf;
    return $self;
}

sub _build_table_info {
    my ($c, $lf, $model, $tab) = @_;

    my $ti = $lf->{table_info}->{ $model } = {};
    if ($tab == 1) {
        # convenience reference to the main table info, for the templates
        $lf->{main} = $ti; weaken $lf->{main};
    }

    my $source = $c->model($model)->result_source;
    $ti->{title} = _m2title($model);
    $ti->{table} = $source->from;
    $ti->{moniker} = $source->source_name;
    $ti->{path} = _m2path($ti->{moniker});
    $lf->{tab_order}->{ $model } = $tab;

    # column and relation info for this table
    my (%mfks, %sfks, %fks);
    my @cols = $source->columns;

    my @rels = $source->relationships;
    foreach my $r (@rels) {
        my $type = $source->relationship_info($r)->{attrs}->{accessor};
        if ($type eq 'multi') {
            $mfks{$r} = $source->relationship_info($r);
        }
        elsif ($type eq 'single') {
            $sfks{$r} = $source->relationship_info($r);
        }
        else { # filter
            $fks{$r} = $source->relationship_info($r);
        }
    }

    # mas_many cols
    foreach my $t (keys %mfks) {
        # make friendly human readable title for related table
        $ti->{mfks}->{$t} = _2title($t);
    }

    $ti->{pk} = ($source->primary_columns)[0];
    $ti->{col_order} = [
        $ti->{pk},                                           # primary key
        (grep {!exists $fks{$_} and $_ ne $ti->{pk}} @cols), # ordinary cols
    ];

    # consider table columns
    foreach my $col (@cols) {
        my $info = $source->column_info($col);

        $ti->{cols}->{$col} = {
            heading      => _2title($col),
            editable     => ($info->{is_auto_increment} ? 0 : 1),
            required     => ((exists $info->{is_nullable}
                                 and $info->{is_nullable} == 0) ? 1 : 0),
        };

        $ti->{cols}->{$col}->{default_value} = $info->{default_value}
            if $info->{default_value} and $ti->{cols}->{$col}->{editable};

        if (exists $xtype_for{ $info->{data_type} }) {
            $ti->{cols}->{$col}->{extjs_xtype}
                = $xtype_for{ $info->{data_type} };

            $ti->{cols}->{$col}->{extjs_xtype_extra}
                = $extra_for{ $ti->{cols}->{$col}->{extjs_xtype} }
                if exists $extra_for{ $ti->{cols}->{$col}->{extjs_xtype} };
        }
    }

    # extra data for foreign key columns
    foreach my $col (keys %fks, keys %sfks) {

        $ti->{cols}->{$col}->{fk_model} =
             _moniker2model($c, $source->related_source($col)->source_name);

        # override the heading for this col to be the foreign table name
        $ti->{cols}->{$col}->{heading} =
            _m2title( $ti->{cols}->{$col}->{fk_model} );

        # all gets a bit complex here, as there are a lot of cases to handle

        # we want to see relation columns unless they're the same as our PK
        # (which has already been added to the col_order list)
        push @{$ti->{col_order}}, $col if $col ne $ti->{pk};

        if (exists $sfks{$col}) {
        # has_one or might_have cols are reverse relations, so pass hint
            $ti->{cols}->{$col}->{is_rr} = 1;
        }
        else {
        # otherwise mark as a foreign key
            $ti->{cols}->{$col}->{is_fk} = 1;
        }

        # relations where the foreign table is the main table are not editable
        # because the template/extjs will complete the field automatically
        if ($source->related_source($col)->source_name
                eq $lf->{main}->{moniker}) {
            $ti->{cols}->{$col}->{editable} = 0;
        }
        else {
        # otherwise it's editable, and also let's call ourselves again for FT
            $ti->{cols}->{$col}->{editable} = 1;

            if ([caller(1)]->[3] !~ m/::_build_table_info$/) {
                _build_table_info(
                    $c, $lf, $ti->{cols}->{$col}->{fk_model}, ++$tab);
            }
        }
    }
}

sub _moniker2model {
    my ($c, $moniker) = @_;
    return first { $_ =~ m/^(?:\w+::){0,}$moniker$/i } $c->models;
}

sub _qualify2package {
    return join '::', map { join '', split /[\W_]+/, lc } @_;
        # from DBIx::Class::Schema::Loader::Base::_table2moniker
}

# make friendly human readable title for this table
sub _m2title {
    my $model = shift;

    my @title = split '::', $model;
    shift @title if $title[0] =~ m/^DBIC$/i; # drop our Model namespace
    s/(\w)([A-Z][a-z0-9])/$1 $2/g for @title; # reverse _table2moniker, ish
    return join ' ', @title;
}

sub _m2path {
    return join '/', map lc, split '::', shift;
}

sub _2title {
    return join ' ', map ucfirst, split /[\W_]+/, lc shift;
}

1;
__END__
