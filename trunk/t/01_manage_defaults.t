use Test::More 'no_plan';
use Test::Exception;

use_ok('DBIx::Class::FormFuBuilder');
can_ok('DBIx::Class::FormFuBuilder', qw(form_fu_form_default form_fu_extra));

# just a ref for easier access
no warnings;
my $info = \%DBIx::Class::FormFuBilder::info;
my $class = 'DBIx::Class::FormFuBuilder';

# empty it
is_deeply($info, {}, 'info initially empty');

# check form_default accessor
is_deeply($class->form_fu_form_default, {}, 'reading accessor 1 works');
lives_ok { $class->form_fu_form_default({a => 42, b => 'ccc'}) } 'setting hashref 1 works';
# dies_ok { $class->form_fu_form_default('scalar value') } 'setting scalar dies';
# dies_ok { $class->form_fu_form_default(['array','scalar value']) } 'setting arrayref dies';
is_deeply($class->form_fu_form_default, {a => 42, b => 'ccc'}, 'reading accessor 2 works');
lives_ok { $class->form_fu_form_default({b => 'ddd'}) } 'setting hashref 2 works';
is_deeply($class->form_fu_form_default, {a => 42, b => 'ddd'}, 'reading accessor 3 works');

{
    # a fake package for accessing column_info
    package Column;
    our %column_info_for = (
        map { ($_ => {extras => {}}) }
        qw(col1 col2 col3)
    );
    
    # simulate load_components
    *form_fu_extra = *DBIx::Class::FormFuBuilder::form_fu_extra;
    
    # fake column_info getter
    sub column_info {
        my $self = shift;
        my $column = shift;
        
        die "No such column '$column'"
            unless exists($column_info_for{$column});
        return $column_info_for{$column};
    }
}

# fake a resultset
my $resultset = 'Column';

# check extra accessors
can_ok($resultset, qw(form_fu_extra column_info));
lives_ok {$resultset->column_info('col1')} 'accessing a known column works';
dies_ok {$resultset->column_info('colx')} 'accessing an unknown column dies';

is(ref($resultset->column_info('col1')), 'HASH', 'column info is hashref');
ok(exists($resultset->column_info('col1')->{extras}), 'column info has extras');
is_deeply($resultset->column_info('col1')->{extras}, {}, 'column info initially empty');

# set/retrieve some extras
lives_ok {$resultset->form_fu_extra(col1 => {label => 'The Label is'})} 'setting an extra works';
dies_ok {$resultset->form_fu_extra()} 'setting an unnamed column dies';
lives_ok {$resultset->form_fu_extra('col1')} 'retrieving an extra works';

is_deeply($resultset->column_info('col1')->{extras}, {formfu => {label => 'The Label is'}}, 'column info set');
is_deeply($resultset->form_fu_extra('col1'), {label => 'The Label is'}, 'column info retrievable');
is_deeply($resultset->column_info('col2')->{extras}, {}, 'other column info unchanged');

# check form_fu_extra with contraint/s filter/s and scalar/array/hashref things...

$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraint => 'Required'});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Required'}]}, 
          'setting a scalar constraint works');

$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraints => 'Number'});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Number'}]}, 
          'setting a scalar constraints entry works');
          
$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraint => {type => 'Text'}});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Text'}]}, 
          'setting a hashref onstraint entry works');
          
$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraints => {type => 'Blank'}});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Blank'}]}, 
          'setting a hashref constraints entry works');
          
$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraint => ['Number']});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Number'}]}, 
          'setting a arrayref constraint entry works');

$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {constraints => ['Xxx']});
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Xxx'}]}, 
          'setting a arrayref constraints entry works');

$resultset->column_info('col2')->{extras} = {formfu => {}};
$resultset->form_fu_extra(col2 => {
                            constraint => 'Number',
                            constraints => ['Required', {type => 'Regex'}],
                          });
is_deeply($resultset->form_fu_extra('col2'), 
          {constraints => [{type => 'Number'},{type => 'Required'}, {type => 'Regex'}]}, 
          'setting a mixed constraint/s entry works');

# and so on... more cases...


