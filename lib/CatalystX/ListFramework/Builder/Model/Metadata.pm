package CatalystX::ListFramework::Builder::Model::Metadata;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Component';

use List::Util qw(first);
use Scalar::Util qw(weaken);

my %xtype_for = (
    boolean => 'checkbox',
);

$xtype_for{$_} = 'numberfield' for (
    'bigint',
    'bigserial',
    'dec',
    'decimal',
    'double precision',
    'float',
    'int',
    'integer',
    'mediumint',
    'money',
    'numeric',
    'real',
    'smallint',
    'serial',
    'tinyint',
    'year',
);

$xtype_for{$_} = 'timefield' for ( 
    'time',
    'time without time zone',
    'time with time zone',
);

$xtype_for{$_} = 'datefield' for ( 
    'date',
);

$xtype_for{$_} = 'xdatetime' for (
    'datetime',
    'timestamp',
    'timestamp without time zone',
    'timestamp with time zone',
);

sub process {
    my ($self, $c) = @_;
    my $lf = $c->stash->{lf} = {};

    # set up databases list, even if only to display to user
    _build_db_info($c, $lf);

    # only one db anyway? pretend the user selected that
    $c->stash->{db} = [keys %{$lf->{dbpath2model}}]->[0]
        if scalar keys %{$lf->{dbpath2model}} == 1;

    # no db specified, or unknown db
    return if !defined $c->stash->{db}
            or !exists $lf->{dbpath2model}->{ $c->stash->{db} };

    $c->stash->{dbtitle} = _2title( $c->stash->{db} );

    # set up tables list, even if only to display to user
    my $try_schema = $c->model( $lf->{dbpath2model}->{ $c->stash->{db} } )->schema;
    foreach my $m ($try_schema->sources) {
        my $t = $c->model($m)->result_source->from;
        $lf->{table2path}->{ _2title($t) } = $t;
        $lf->{path2model}->{$c->stash->{db}}->{$t} = $m;
    }

    # no table specified, or unknown table
    return if !defined $c->stash->{table}
        or !exists $lf->{path2model}->{ $c->stash->{db} }->{ $c->stash->{table} };

    $lf->{model}
        = _model_for( $c, $lf->{path2model}->{ $c->stash->{db} }->{ $c->stash->{table} } );

    _build_table_info($c, $lf, $lf->{model}, 1);

    #use Data::Dumper;
    #die Dumper $lf;

    return $self;
}

sub _build_db_info {
    my ($c, $lf) = @_;
    my %sources;

    MODEL:
    foreach my $m ($c->models) {
        my $model = $c->model($m);
        next unless eval { $model->isa('Catalyst::Model::DBIC::Schema') };
        foreach my $s (keys %sources) {
            if (eval { $model->isa($s) }) {
                delete $sources{$s};
            }
            elsif (eval { $c->model($s)->isa($m) }) {
                next MODEL;
            }
        }
        $sources{$m} = 1;
    }

    foreach my $s (keys %sources) {
        my $name = $c->model($s)->storage->dbh->{Name};

        if ($name =~ m/\W/) {
            # SQLite will return a file name as the "database name"
            $name = lc [ reverse split '::', $s ]->[0];            
        }

        $lf->{db2path}->{_2title($name)} = $name;
        $lf->{dbpath2model}->{$name} = $s;
    }
}

sub _build_table_info {
    my ($c, $lf, $model, $tab) = @_;

    my $ti = $lf->{table_info}->{ $model } = {};
    if ($tab == 1) {
        # convenience reference to the main table info, for the templates
        $lf->{main} = $ti; weaken $lf->{main};
    }

    my $source = $c->model($model)->result_source;
    $ti->{table}   = $source->from;
    $ti->{path}    = $ti->{table};
    $ti->{title}   = _2title($ti->{table});
    $ti->{moniker} = $source->source_name;
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
        next unless defined $info;

        $ti->{cols}->{$col} = {
            heading      => _2title($col),
            editable     => ($info->{is_auto_increment} ? 0 : 1),
            required     => ((exists $info->{is_nullable}
                                 and $info->{is_nullable} == 0) ? 1 : 0),
        };

        $ti->{cols}->{$col}->{default_value} = $info->{default_value}
            if ($info->{default_value} and $ti->{cols}->{$col}->{editable});

        $ti->{cols}->{$col}->{extjs_xtype} = $xtype_for{ lc($info->{data_type}) }
            if (exists $info->{data_type} and exists $xtype_for{ lc($info->{data_type}) });
    }

    # extra data for foreign key columns
    foreach my $col (keys %fks, keys %sfks) {

        $ti->{cols}->{$col}->{fk_model}
            = _model_for( $c, $source->related_source($col)->source_name );
        next if !defined $ti->{cols}->{$col}->{fk_model};

        # override the heading for this col to be the foreign table name
        $ti->{cols}->{$col}->{heading} =
            _2title( $c->model( $ti->{cols}->{$col}->{fk_model} )->result_source->from );

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

# find catalyst model which is serving this DBIC result source
sub _model_for {
    my ($c, $moniker) = @_;

    foreach my $m ($c->models) {
        my $model = $c->model($m);
        my $test = eval { $model->result_source->source_name };
        next if !defined $test;

        return $m
            if $model->result_source->source_name eq $moniker;
    }
    return undef;
}

# col/table name to human title
sub _2title {
    return join ' ', map ucfirst, split /[\W_]+/, lc shift;
}

1;
__END__
