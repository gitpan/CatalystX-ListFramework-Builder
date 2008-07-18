package CatalystX::ListFramework::Core;

use strict;
use warnings FATAL => 'all';
require 5.8.1;

use base qw(Class::Data::Inheritable);
use CatalystX::ListFramework::Util;
use Scalar::Util qw(blessed);
use Carp;

__PACKAGE__->mk_classdata('formdefs' => {});

sub new {
    my ($class, $type, $c) = @_;
    if (exists $class->formdefs->{$type}) {
        # Return the cached instance but refresh the Catalyst context
        $class->formdefs->{$type}->{c} = $c;
        return $class->formdefs->{$type};
    }

    my $self = bless {
        formdef => {},
        c => $c,
        name => $type
    }, $class;

    $class->formdefs->{$type} = $self;
    $self->build_formdef; # auto-gen from DBIC reflection
    my $formdef = $self->{formdef};

    if ($c->config()->{'formdef_path'}) {
        my $FORMDEF_PATH = $c->config()->{'formdef_path'}
            or croak "formdef_path not set in config";

        ## Eval the master/ form file, then the site/ file
        for my $file ("$FORMDEF_PATH/master/$type.form",
                      "$FORMDEF_PATH/site/$type.form")
        {
            my $return = undef;
            unless ($return = do $file) {
                croak "couldn't parse $file: $@" if $@;
               #croak "couldn't do $file: $!"    unless defined $return;
               #croak "couldn't run $file"       unless $return;
            }
            # inject the loaded data into formdef,
            # overriding what we generated in build_formdef
            @{$formdef}{keys %$return} = (values %$return);
        }
    }

    foreach my $column_id (keys %{$formdef->{columns}}) {
        # Set a default 'order_by' value
        my $col = $formdef->{columns}->{$column_id};
        unless (exists $col->{order_by}) {
            $col->{order_by} = $col->{field};
            if (ref($col->{order_by})) {
                croak "Compound column $column_id must have order_by property";
            }
        }
    }
    $formdef->{columns}->{OBJECT}->{form_type} = $type;
    $formdef->{columns}->{OBJECT}->{model} = $formdef->{model};
        # to help in autocompletes, where we just get an OBJECT column id
    
    foreach my $search (keys %{$formdef->{searches}}) {
        my $s = $formdef->{searches}->{$search};
        # Set a default match operator
        $s->{op} = '=' if (!defined $s->{op});
        # Set a default html type
        $s->{html_type} = 'Textfield' if !defined $s->{html_type};
    }
    
    return $self;        
}

sub build_table_data {
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};
    my $params = $c->req->params;

    my $table = shift || $name;
    my $prefix = ($table eq $name ? '' : "$table.");
    my $data = {};

    foreach my $col (@{ $formdef->{infoboxes}->{ $table } }) {
        next if ($col->{id} =~ m/\./) and $col->{not_editable};

        if ($col->{id} !~ m/(.+)\@OBJECT/) {
            next unless $params->{ $col->{id} };
            (my $unqual_col = $col->{id}) =~ s/^$prefix//;

            $data->{ $unqual_col } = $params->{ $col->{id} };
        }
        else {
            my $id = $1;
            (my $unqual_col = $id) =~ s/^$prefix//;

            next unless exists $formdef->{uses}->{$unqual_col};
            my $ft = $formdef->{uses}->{$unqual_col};

            next if exists $params->{ "checkbox.$ft" };
            next unless $params->{ "combobox.$id\@OBJECT" };

            # skip FKs where the value is the same as the current DB val
            # a bit nasty to hit the DB for this, but it's the least hacky of
            # each hacky option.
            if ($table eq $name) {
                my $pk = $formdef->{columns}->{OBJECT}->{primary_key};
                if (exists $data->{ $pk } and $data->{ $pk } ne '') {
                    my $current_val = $c->model($formdef->{model})
                                        ->find( $data->{ $pk } )->$unqual_col;
                    next if
                        $current_val eq $params->{ "combobox.$id\@OBJECT" };
                }
            }

            $data->{ $unqual_col } = $params->{ "combobox.$id\@OBJECT" };
        }
    }

    return $data;
}

sub jupdate_from_query {  # Update a record. Probably called from an infobox screen
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};
    my $params = $c->req->params;

    my $data = $self->build_table_data; # main table

    my $pk = $formdef->{columns}->{OBJECT}->{primary_key};
    my $row = ( (exists $data->{ $pk } and $data->{ $pk } ne '')
        ? $c->model($formdef->{model})->find( $data->{ $pk } )->set_columns( $data )
        : $c->model($formdef->{model})->new_result( $data ) );

    foreach my $param (keys %$params) {
        next unless $param =~ m/^checkbox\.([^.]+)$/;
        my $ftable = $1;
        my $related_data = $self->build_table_data($ftable); # related table
        my $fk = $formdef->{used}->{$ftable};

        $row->set_column( $fk =>
            # you'd think create_related would work, but OH NO
            $row->result_source->related_source($fk)
                ->resultset->create($related_data)->id
        );
    }

    $c->stash->{'success'} = ($row->update_or_insert ? 'true' : 'false');
    return $self;
}

sub jdelete {
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};
    my $params = $c->req->params;

    my $row = eval { $c->model($self->{formdef}->{model})->find($params->{key}) };

    if (blessed $row) {
        $row->delete;
        $c->stash->{'success'} = 'true';
    }
    else {
        $c->error('Failed to retrieve row');
        $c->stash->{'success'} = 'false';
    }

    return $self;
}

sub jget_stringified {
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};

    my $pg    = $c->req->params->{'page'}  || 1;
    my $limit = $c->req->params->{'limit'} || 5;
    my $query = $c->req->params->{'query'} || '';
    my $fk    = $c->req->params->{'fkname'};
    
    $fk =~ s/^[^.]*\.//; $fk =~ s/\s+$//;
    $query = ($query ? qr/\Q$query\E/ : qr/./);

    my $rs = $c->model($self->{formdef}->{model})
                ->result_source->related_source($fk)->resultset;

    my @data =  map  { { dbid => $_->id, stringified => "$_" } }
                grep { "$_" =~ m/$query/ } $rs->all;
    @data = sort { $a->{stringified} cmp $b->{stringified} } @data;

    my $page = Data::Page->new;
    $page->total_entries(scalar @data);
    $page->entries_per_page($limit);
    $page->current_page($pg);

    $c->stash->{rows} = [ $page->splice(\@data) ];
    $c->stash->{total} = $page->total_entries;

    return $self;
}

sub stash_json_list {
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};

    my $page  = $c->req->params->{'page'}  || 1;
    my $limit = $c->req->params->{'limit'} || 10;
    my $sort  = $c->req->params->{'sort'}  || $formdef->{pks}->[0];
    (my $dir  = $c->req->params->{'dir'}   || 'ASC') =~ s/\s//g;

    my $list_columns = $self->{formdef}->{display}->{default}
        or confess("No columns defined for view default"); # TODO more views
    my $join_arg = $self->join_arg_from_columns($list_columns);

    my $search_opts = {
        'join' => $join_arg, 'prefetch' => $join_arg,
        'page' => $page, 'rows' => $limit,
    };

    # Copy metadata (headings etc) from 'columns' (maybe in a related form
    # file) to 'display'
    $self->copy_metadata_from_columns($list_columns);

    # As we've copied metadata from 'columns' to 'display', we can just grep
    # display for the ID we've been passed and get the order_by info from
    # there.
        
    my ($order_column) = grep {$_->{id} eq $sort} (@$list_columns) or die
        "Can't find a column with id $sort";

    # FIXME this is untested
    if ($sort !~ m/\@OBJECT$/) {
        my @orders = ref($order_column->{order_by}) ? @{$order_column->{order_by}}
                                                    : $order_column->{order_by};

        my $sql_table = 'me';
        if ($sort =~ m{(.+\.)?(\w+)\.\w+$}) {
            $sql_table = $2;
        }
        foreach my $sql_column (@orders) {
            push @{$search_opts->{order_by}}, \"$sql_table.$sql_column $dir";
        }
    }

    # find filter fields in UI form
    my @filterfields = ();
    foreach my $p (keys %{$c->req->params}) {
        next unless $p =~ m/^search\.(.+)/;
        push @filterfields, $1;
    }

    # construct search clause if any of the filter fields were filled in UI
    my $filter = {
        map {
            ( $_ => { -like => '%'. $c->req->params->{"search.$_"} .'%' } )
        } @filterfields
    };

    my $rs = $c->model($self->{formdef}->{model})->search($filter, $search_opts);
    my @processed;

    # make data structure for JSON output
    while (my $row = $rs->next) {
        my $processed = $self->rowobject_to_columns($row, $list_columns);
        my $data = {};
        foreach my $col (@$list_columns) {
            $data->{$col->{id}} = (defined $processed->{$col->{id}} ?
                "$processed->{$col->{id}}" : ''); # stringify
        }
        push @{$c->stash->{rows}}, $data;
    }

    if ($sort =~ m/\@OBJECT$/) {
        @{$c->stash->{rows}} = sort {
            $dir eq 'ASC' ? ($a->{$sort} cmp $b->{$sort})
                          : ($b->{$sort} cmp $a->{$sort})
        } @{$c->stash->{rows}};
    }

    $c->stash->{rows} ||= {};
    $c->stash->{total} = $rs->pager->total_entries || 0;

    return $self;
}

1;

__END__
