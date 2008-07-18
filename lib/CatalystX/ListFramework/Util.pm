package CatalystX::ListFramework::Core;

use strict;
use warnings FATAL => 'all';
require 5.8.1;

use List::Util qw(first);
use List::MoreUtils qw(uniq);
use Carp;

# XXX only works for simple single model applications
# but if you want fancy, just write the formdef file
sub build_formdef {
    my $self = shift;
    my ($name, $c, $formdef) =
        @{$self}{qw(name c formdef)};

    my $table = ucfirst $name;
    my $model = first { $_ =~ m/::$table$/ } $c->models;

    return if !defined $model;
    my $source = $c->model($model)->result_source;

    $formdef->{model} = $model;
    $formdef->{title} = $table;
    $formdef->{create_uri} = "/create/$name";
    $formdef->{delete_uri} = "/delete/$name";
    $formdef->{searches} = {};
    $formdef->{infobox_order}->{$name} = 1;
    my $box_count = 1;

    my @cols = $source->columns;
    my %pks  = map {$_ => 1} $source->primary_columns;
    $formdef->{pks} = [ keys %pks ];

    my %fks = ();
    my @rels = $source->relationships;
    foreach my $r (@rels) {
        next if $source->relationship_info($r)
                    ->{attrs}->{accessor} eq 'multi';
        # we want belongs_to, might_have and has_one
        $fks{$r} = $source->relationship_info($r);
    }
    $formdef->{fks} = [ keys %fks ];

    foreach my $col (uniq @cols, keys %fks) {
        my $info = ( scalar (grep {$_ eq $col} @cols)
            ? $source->column_info($col) : {} );
        my $auto = ($info->{is_auto_increment} ? 1 : 0);
        my $reqd = ((!exists $info->{is_nullable}
            or $info->{is_nullable}) ? 0 : 1);
        (my $cn = ucfirst $col) =~ s/_/ /g;

        if (exists $pks{$col}) {
            # is primary key of main table
            # might be read-only (auto inc), probably also required

            $formdef->{columns}->{OBJECT} = {primary_key => $col};
            $formdef->{columns}->{$col} = {
                field => $col, heading => $cn};

            push @{$formdef->{display}->{default}},
                 {id => $col, heading => $cn, uri => "/get/$name/"};

            push @{$formdef->{infoboxes}->{$name}}, {
                 id => $col,
                 heading => $cn,
                 not_editable => $auto,
                 required => $reqd,
            };
        }
        elsif (exists $fks{$col}) {
            # is foreign key in the main table
            # might be required, unlikely to be read-only (auto inc)

            (my $fn = $fks{$col}->{source}) =~ s/^.+:://;
            my $fname = lc $fn;

            $formdef->{infobox_order}->{$fname} = ++$box_count;
            $formdef->{uses}->{$col} = $fname;
            $formdef->{used}->{$fname} = $col;

            $formdef->{columns}->{$col} = {
                field => $col, heading => $fn };

            push @{$formdef->{display}->{default}}, {
                 id => "$col\@OBJECT",
                 heading => $fn,
                 uri => "/get/$fname/",
            };

            push @{$formdef->{infoboxes}->{$name}}, {
                 id => "$col\@OBJECT",
                 heading => $fn,
                 required => $reqd,
            };

            # process infobox for related table
            my $fsource = $source->schema->source($fn);
            my @fcols   = $fsource->columns;
            my @fpks    = $fsource->primary_columns;
            my @frels   = $fsource->relationships;

            foreach my $fcol (@fcols) {
                my $finfo = $fsource->column_info($fcol);
                my $fauto = ($finfo->{is_auto_increment} ? 1 : 0);
                my $freqd = ($finfo->{is_nullable} ? 0 : 1);
                (my $fcn = ucfirst $fcol) =~ s/_/ /g;

                if (grep { $_ eq $fcol } @frels) {
                    # is foreign key in the foreign table
                    # might be required, unlikely to be read-only (auto inc)

                    my $ffname =
                        lc $fsource->relationship_info($fcol)->{source};
                    $ffname =~ s/^.+:://;
                    $formdef->{uses}->{$fcol} = $ffname;
                    $formdef->{used}->{$ffname} = $fcol;

                    push @{$formdef->{infoboxes}->{$fname}}, {
                         id => "$fname.$fcol\@OBJECT",
                         heading => $fcn,
                         required => $freqd,
                    };
                }
                else {
                    # is other col (primary or ordinary) in the foreign table
                    # might be read-only (auto-inc), might be required

                    push @{$formdef->{infoboxes}->{$fname}}, {
                         id => "$fname.$fcol",
                         heading => $fcn,
                         not_editable => $fauto,
                         required => $freqd,
                    };
                }
            }

        }
        else {
            # regular column
            # might be read-only (auto-inc), might be required

            $formdef->{columns}->{$col} = {
                field => $col, heading => $cn };
            $formdef->{columns}->{$col}->{default_value} =
                $info->{default_value} if $info->{default_value};

            push @{$formdef->{display}->{default}},
                 {id => $col, heading => $cn};

            push @{$formdef->{infoboxes}->{$name}}, {
                 id => $col,
                 heading => $cn,
                 not_editable => $auto,
                 required => $reqd,
            };
        }
    }

    #die Dumper $formdef;
    return $self;
}

sub copy_metadata_from_columns {
    # Copy hash fields like 'heading' and 'field' from formdef->columns to ->display->view or infoboxes 
    my ($self, $destination_columns) = @_;

    foreach my $display_column (@$destination_columns) {
        my $formobj = $self;
        my $display_column_id = $display_column->{id};
        while ($display_column_id =~ m{^(\w+)[.@](.+)}) {
            my $formdeftype_for_relationship = $formobj->{formdef}->{uses}->{$1}
                or die "Relationship $1 in $1.$2 isn't specified in 'uses'";
            $formobj = __PACKAGE__->new($formdeftype_for_relationship, $formobj->{c});
            $display_column_id = $2;
        }
        my $column_metadata = $formobj->{formdef}->{columns}->{$display_column_id} or die "No such column - $display_column_id";
        foreach my $k (keys %$column_metadata) {
            $display_column->{$k} = $column_metadata->{$k} unless (exists $display_column->{$k});
        }
    }
}

sub rowobject_to_columns {
    # Given a row object from the base table and a list of columns to display, return a hashref of col_id => cell_data
    
    my ($self, $db_row_obj, $list_columns) = @_;
    my $processed_row = {};
    foreach my $col (@$list_columns) {
        # To get a column from $db_row, eval '$row = $row->rel' on each bit of $col->{id} up to the last dot,
        # then eval $row->($col->{field})
        my $row_in_wanted_table = $db_row_obj;
        {
            my $col_id = $col->{id};
            while ($col_id =~ m{^(\w+)[.@](.+)}) { # work along the abc.def.ghi relationships til we get to the final row obj we want
                $row_in_wanted_table = eval("\$row_in_wanted_table->$1");
                if ($@) { die "Eval of row->$1 failed"; }
                $col_id = $2;
            }
        }
        
        if ($col->{id} =~ m{\@OBJECT$}) { # called from stash_infoboxes and requesting the whole row-object
            $processed_row->{$col->{id}} = $row_in_wanted_table;
            next; # skip processing $field, cos it won't have one
        }
            
        my $cell = "";
        my @fields = ref($col->{field})?(@{$col->{field}}):($col->{field});
        foreach my $field (@fields) {
            if (ref($field) eq 'SCALAR') {  # literal text
                $cell .= $$field;
            }
            elsif ($field =~ /^(\w+)\((.+)\)/) {  # requesting helper $1 on data from dbic call $2
                my $tmp;
                eval "\$tmp = \$row_in_wanted_table->$2";
                if ($@) { die "Eval of row->$2 failed"; }
                eval "\$cell .= \&CatalystX::ListFramework::Helpers::$1(\$tmp, \$self->{c}, \$self->{formdef})";
                confess "Helper call failed: $@" if ($@);
            }
            else { # a simple column name. NB: field can't have dots any more - that's what id is for
                if ($#fields == 0) {
                    eval "\$cell = \$row_in_wanted_table->$field";  # this allows $cell to be an object; not normal in a listing
                    if (ref $cell) {warn '*-*-* Setting cell to an object. Is this really necessary?';}
                }
                else {
                    eval "\$cell .= \$row_in_wanted_table->$field"; # append to $cell if multiple fields (CAN'T BE AN OBJECT!)
                }
                die "Setting cell failed: $@" if ($@);
                if (defined $col->{type}) {
                    eval "\$cell = \&CatalystX::ListFramework::Helpers::Types::$col->{type}(\$cell, \$self->{c}, \$self->{formdef})";
                    confess "Type-helper call failed: $@" if ($@);
                }
            }
        }
        
        $processed_row->{$col->{id}} = $cell;
    }
    return $processed_row;
}

sub join_arg_from_columns {
    my ($self, $list_columns) = @_;
    # Formulate 'join' and 'prefetch' arguments for the DBIC call.
    # Join is for the relationships we search on. Prefetch is for the data we display.

    # join => ['rel', {rel1=>'rel2'}, {rel1=>{rel2=>'rel3'}}, ...] # depending how many dots we have to follow
    
    my %prefetches_seen;
    foreach my $column (@$list_columns) {
        my $prefetch;
        my @path = reverse(split(/\./, $column->{id}));
        next if (scalar(@path) == 1);  # no dots, just a local column
        shift @path;  # junk the column part
        $prefetches_seen{join('.', @path)}++;
    }
    
    # If we're using rel1 and rel1.rel2, this gives join_arg = 'rel1', {rel1=>'rel2'} which is fine but DBIC seems
    # to then join both rels multiple times, e.g. as rel2_2 etc, which is harmless but annoying.
    
    # In the end, just set join=> and prefetch=> to the same thing. DBIC == join proliferation.
    # Prefetch of {rel1=>'rel2'} prefetches both rel1.* and rel2.* - surely a misbehaviour?

    my %joins_seen = %prefetches_seen;  # anything prefetched must also be joined, but we need to spot unnecessary joins first
    foreach my $column (@{$self->{formdef}->{search}}) {
        my $join;
        my @path = reverse(split(/\./, $column->{id}));
        next if (scalar(@path) == 1);  # no dots, just a local column  (this is why I've not rejigged the wasteful split/join/split)
        shift @path;  # junk the column part
        $joins_seen{join('.', @path)}++;
    }
    my @joins_needed = keys %joins_seen;
    # If we have 'album' and 'artist.album' then only 'artist.album' is needed.
    my $deeper_join_exists = sub {
        my $join = shift;
        my @joins = keys %joins_seen;
        foreach (@joins) {
            return 1 if (m{\.$join$});
        }
        return 0;
    };
    @joins_needed = grep { !&$deeper_join_exists($_); } (@joins_needed);
    
    my $join_arg = [];
    foreach (@joins_needed) {
        my @path = split(/\./);
        my $join;
        foreach my $element (@path) {
            if (!defined($join)) {
                $join = $element;   
            }
            else {
                $join = {$element => $join};   
            }
        }
        push @$join_arg, $join;
    }
    #warn Dumper($join_arg);
    $join_arg;
}

sub get_listing_columns {
    my ($self, $view) = @_;
    confess if (!$view);
    return @{$self->{formdef}->{display}->{$view}};
}

1;
__END__
