package DBIx::Class::FormFuBuilder;
use strict;
use warnings;

our $VERSION = '0.01';

#
# save our info here.
#
our %info;

=head1 NAME

DBIx::Class::FormFuBuilder

=head1 SYNOPSIS

    ### STILL UNDER HEAVY CONSTRUCTION
    ### USE AT OWN RISK!!!

    # inside your Model class:
    package YourApp::Model::DB;
    ...
    DBIx::Class->load_components('FormFuBuilder');
    
    
    # inside your Schema class (optionally) do:
    package DemoApp::Schema;
    ...
    # defaults for entire forms
    __PACKAGE__->form_fu_form_default({
        ... # standard form definitions like CSS, ...
    });
    
    # defaults for 'integer'
    __PACKAGE__->form_fu_type_default(integer => {
        ... # meaningful defaults for 'integer' fields
    });
    
    # defaults for 'varchar' -- could 'character_varying' make sense???
    __PACKAGE__->form_fu_type_default('character varying' => {
        ### how to handle eg. size ???
    });

    
    # inside your result classes do this:
    package DemoApp::Schema::Result::Product;
    ...
    __PACKAGE__->form_fu_extra(column_name => {...});
    
    
    # at any place you need a form from a $result_set
    my $form = $result_set->generate_form_fu({...});

more examples to come!

=head1 DESCRIPTION


=head1 METHODS

=cut

=head2 form_fu_form_default

set general defaults for every form as a hashref

=cut

sub form_fu_form_default {
    my $self = shift;
    
    my $form_default = ($info{form} ||= {});
    _merge_into_hash($form_default, @_) if (@_);
    return $form_default
}

=head2 form_fu_type_default

specify defaults for a given SQL-Datatype

=cut

sub form_fu_type_default {
    my $self = shift;
    my $datatype = shift;
    
    die "datatype must be a string"
        if (ref($datatype) || !$datatype);
    
    my $type_default = ($info{type}->{$datatype} ||= {});
    _merge_into_hash($type_default, @_) if (@_);
    return $type_default;
}

=head2 form_fu_extras

specify some extra(s) that get into the {extra}->{form_fu} hash of a column

meaningful things could be:

=over 

=item title

=item label

=item constraint(s)

=item filter(s)

=back

=cut

sub form_fu_extra {
    my $self = shift;
    my $column_name = shift;
    
    die 'no column name given' if (!$column_name);
    
    my $form_fu_extra = 
        ($self->column_info($column_name)->{extras}->{formfu} ||= {});
    _merge_into_hash($form_fu_extra, @_) if (@_);
    return $form_fu_extra
}

=head2 generate_form_fu

generate a form from a resultset including all joined tables

additionally a hash or a hashref with args may be added. Meaningful keys could be:

=over

=item action

=item constraints

=item indicator

if an indicator is given but no submit field present, it will get autogenerated at the end of the form

=item auto_fieldset

=item auto_constraint_class

=item attributes

=item elements

these elements will go to the beginning of the form

=item append

this is an additional element-array inserted at the end of the form

=back

=cut

sub generate_form_fu {
    my $rs = shift;
    my %args = ( ref($_[0]) eq 'HASH' ? %{$_[0]} : @_ );
    
    die 'only usable on classes derived from "DBIx::Class::ResultSet"'
        unless $rs->isa('DBIx::Class::ResultSet');
        
    my $result_source = $rs->result_source;
    
    ### FIXME: is there a way to avoid this bad back???
    ### fire this query would be a solution but takes time :-(
    my $dummy = $rs->_resolved_attrs;
    
    #
    # build form scaffolding merging singular things into plural...
    #
    my $append = delete $args{append};
    $args{elements} = [] if (ref($args{elements}) ne 'ARRAY');
    
    my %form = (
        attributes => {},
        %args,
    );
    
    #
    # add elements
    #
    $rs->_add_elements($result_source => $form{elements},
                       $rs->{_attrs}->{alias} || 'me',
                       @{$rs->{_attrs}->{select}} );

    push @{$form{elements}}, (ref($append) eq 'ARRAY' ? (@{$append}) : $append)
        if ($append);

    if ($args{indicator}) {
        push @{$form{elements}}, {
            type => 'Submit',
            name => $args{indicator},
            value => $args{indicator},
            label => ' ',
        };
    }
    
    #
    # done :-)
    #
    return \%form;
}

#
# helper: merge things into a hash
#         internally 'filters' and 'constraints' are handled
#         as a hashref, later they are expanded to an array-ref
#         this is for keeping the different types unique easily
#
sub _merge_into_hash {
    my $hash = shift;
    
    return if (!scalar(@_) || !$_[0]);
    
    my %args = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;
    
    # handle contraint/filter different
    foreach my $s qw(constraint filter) {
        # $s = singular, $p = plural
        my $p = "${s}s";
        
        # remove unwanted things
        if (exists($args{"-$s"}) || exists($args{"-$p"})) {
            # OK, we have something to remove...
            
            delete $hash->{$p}->{$_}
                for ( map { ref($_) eq 'HASH' ? $_->{type} : $_ } # get type
                      map { ref($_) eq 'ARRAY' ? @{$_} : $_ }     # un-array-ify
                      grep { $_ }                                 # no undef's
                      ($args{"-$s"}, $args{"-$p"}) );
        }
        
        # add more things
        if (exists($args{$s}) || exists($args{$p})) {
            $hash->{$p}->{$_->{type}} = $_
                for ( grep { warn $_->{type}; 1 }
                      map { ref($_) eq 'HASH' ? $_ : {type => $_} } # get type
                      map { ref($_) eq 'ARRAY' ? @{$_} : $_ }       # un-array-ify
                      grep { $_ }                                   # no undef's
                      ($args{$s}, $args{$p}) );
        }
    }
    
    # add all other remaining things in
    while (my ($key, $value) = each(%args)) {
        next if ($key =~ m{\A -? (?:constraint|filter) s? \z}xms);
        
        if (ref($value) eq 'HASH' && exists($hash->{$key}) && ref($hash->{$key}) eq 'HASH') {
            # merge hash into hash
            $hash->{$key}->{$_} = $value->{$_}
                for keys(%{$value});
        } else {
            # set key
            $hash->{$key} = $value;
        }
    }
}

#
# helper: convert filters and constraints back to array-refs
#
sub _convert_hash {
    my $hash = shift;
    
    return {
        map {
            m{\A (?:constraints|filters) \z}xms
              ? ($_ => [ sort { $a->{type} cmp $b->{type} } # sorting to allow simple testing
                         values %{$hash->{$_}} ])
              : ($_ => $hash->{$_})
        }
        keys(%{$hash})
    };
}

#
# old version - trash soon
#
sub _merge_into_hash_OLD {
    my $hash = shift;
    
    return if (!scalar(@_) || !$_[0]);
    
    my %args = ref($_[0]) eq 'HASH' ? %{$_[0]} : (@_);

    # special treatment for constraint & filter
    foreach my $s qw(constraint filter) {
        # $p = plural, $s = singular...
        my $p = "${s}s";
        
        # remove unwanted things
        if (exists($hash->{$p}) &&
            (exists($args{"-$s"}) || exists($args{"-$p"})) ) {
            # build remove-list
            my %to_remove = (
                map { ((ref($_) eq 'HASH' ? $_->{type} : $_) => 1) }
                ($args{"-$s"}
                 ? ref($args{"-$s"}) eq 'ARRAY' ? @{$args{"-$s"}} : $args{"-$s"}
                 : ()),
                ($args{"-$p"}
                 ? ref($args{"-$p"}) eq 'ARRAY' ? @{$args{"-$p"}} : $args{"-$p"}
                 : ()),
            );
            warn "about to remove: " . join('/', keys(%to_remove));
            # use Data::Dumper; print STDERR Data::Dumper->Dump([\%to_remove],['remove']);
            $hash->{$p} = [
                grep { !exists($to_remove{$_->{type}}) }
                @{$hash->{$p}}
            ];
        }
        
        # add remaining things if needed
        next if (!exists($args{$s}) && !exists($args{$p}));
        
        my %seen = map { ($_->{type} => 1) }
                   @{$hash->{$p} || []};
        push @{$hash->{$p}}, (
            grep { ref($_) eq 'HASH' &&
                   exists($_->{type}) &&
                   !$seen{$_->{type}}++ }
            map { ref($_) ? $_ : {type => $_} }
            ($args{$s}
             ? ref($args{$s}) eq 'ARRAY' ? @{$args{$s}} : $args{$s}
             : ()),
            ($args{$p}
             ? ref($args{$p}) eq 'ARRAY' ? @{$args{$p}} : $args{$p}
             : ()),
        );
        delete $args{$s};
        delete $args{$p};
    }
    
    # transfer remaining things
    $hash->{$_} = $args{$_}
        for grep {1 || !m{\A-}xms} keys(%args);
}

#
# add all fields from a list starting with alias
#
sub _add_elements {
    my $rs = shift;
    my $result_source = shift;
    my $elements = shift;
    my $alias = shift;
    my @columns = @_;
    
    # warn "add elements: @columns...";
    
    #
    # add hidden ID for primary columns
    #
    my %is_primary = ();
    foreach my $primary_col ($result_source->primary_columns) {
        $is_primary{$primary_col} = 1;
        push @{$elements}, {
            type => 'Hidden',
            name => $primary_col,
        };
    }
    
    #
    # determine relationships
    #
    my @relationships = $result_source->relationships;
    my %has_one;  # my column => foreign result source class
    my %has_many; # relationship_name => 1
    foreach my $rel (@relationships) {
        my $rel_info = $result_source->relationship_info($rel);
        my @rel_fields = map {my $x = $_; $x =~ s{\A self [.]}{}xms; $x;}
                         grep {m{\A self [.]}xms}
                         (%{$rel_info->{cond}});
        if (scalar(@rel_fields) != 1) {
            #
            # Houston - we have a problem. We only can handle 1 field...
            #
        } elsif ($rel_info->{attrs}->{is_foreign_key_constraint}) {
            #
            # looks like a has_one relationship
            #
            $has_one{$rel_fields[0]} = $rel_info;
        } elsif ($is_primary{$rel_fields[0]}) {
            #
            # Looks like a has_many relationship
            #
            $has_many{$rel} = $rel_info;
        } else {
            #
            # TODO: find a condition for many_to_many
            #
        }
    }
    
    #
    # loop over fields
    #
    foreach my $column_with_alias (@columns) {
        # filter out columns we do not want...
        next if ($column_with_alias !~ m{\A $alias [.]}xms);
        
        my $column = $column_with_alias;
        $column =~ s{\A $alias [.]}{}xms;
        next if ($is_primary{$column});
        
        # get the column's info
        my $column_info = $result_source->column_info($column);
        
        # OK we got a field left to generate
        my %field = (
            name        => $column,
            label       => ucfirst($column),
            # will be added later
            # type      => 'Text',
            constraints => {},
            filters     => {},
        );
        
        _merge_into_hash(\%field, $column_info->{extras}->{formfu});
        
        if (exists($has_one{$column})) {
            #
            # has-one relation
            #
            my $source = $has_one{$column}->{source};
            
            $field{type} = 'Select';
            if ($column_info->{is_nullable}) {
                $field{empty_first} = 1;
                $field{empty_first_label} = '- none -';
            }
            my $label_column;
            if ($source->can('name')) {
                $label_column = 'name';
            } else {
                # find first non-index column
                my %is_prim = ( map {($_ => 1)} ($source->primary_columns) );
                foreach my $col (grep {!$is_prim{$_}} $source->columns) {
                    $label_column = $col;
                    last;
                }
            }
            $field{model_config} = {
                resultset    => $has_one{$column}->{source},
                label_column => $label_column,
                attributes   => {
                    order_by => $label_column,
                },
            };
        } else {
            #
            # simple field
            #
            if (!$column_info->{is_nullable}) {
                $field{constraints}->{Required} = {type => 'Required'};
            }
            if ($column_info->{data_type} eq 'numeric') {
                $field{constraints}->{Number} = {type => 'Number'};
            }
            
            _merge_into_hash(\%field, $info{type}->{$column_info->{data_type}});
        }
        
        #
        # add a default type if not yet set
        #
        $field{type} ||= 'Text';
        
        #
        # cleanup a '-' prefixed keys -- dirty, I know...
        #
        delete $field{$_}
            for grep {m{\A-}} keys(%field);
        
        push @{$elements}, _convert_hash(\%field);
    }

    #
    # finally add all has_many relationships
    #
    foreach my $from (@{$rs->{_attrs}->{from}}) {
        next if (ref($from) ne 'ARRAY');
        my ($rel_name) = grep {exists($has_many{$_})} keys(%{$from->[0]});
        next if (!$rel_name);
    
        # we found a has-many relation we would join in a select
        my %repeatable = (
            type         => 'Repeatable',
            nested_name  => $rel_name,
            counter_name => "${rel_name}_count",
            model_config => {
                empty_rows   => 1,
                new_rows_max => 10,
            },
            elements => [],
        );
        
        my @repeat_columns;
        foreach my $column (@columns) {
            next if ($column !~ m{\A $rel_name [.]}xms);
            my $short_col = $column;
            $short_col =~ s{\A \w+ [.]}{}xms;
            next if (grep {m{\A foreign [.] $short_col}xms} %{$has_many{$rel_name}->{cond}});
            push @repeat_columns, $column;
        }
        $rs->_add_elements($has_many{$rel_name}->{source} => $repeatable{elements},
                           $rel_name, @repeat_columns);
        
        push @{$elements}, \%repeatable;
        
        push @{$elements}, {
            type => 'Hidden',
            name => "${rel_name}_count",
        };
    }

}

=head1 AUTHOR

Wolfgang Kinkeldei, E<lt>wolfgang@kinkeldei.deE<gt>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

