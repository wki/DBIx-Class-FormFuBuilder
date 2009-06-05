use Test::More 'no_plan';
use Test::Exception;

use_ok('DBIx::Class');

#
# define a simple schema
#
{
    package Schema::Result::Person;
    
    use base 'DBIx::Class';

    __PACKAGE__->load_components('InflateColumn::DateTime', 'Core');
    __PACKAGE__->table('person');
    __PACKAGE__->add_columns(
        id => {
            data_type => 'integer',
            default_value => q{nextval('person_id_seq'::regclass)},
            is_nullable => 0,
            size => 4,
        },
        name => {
            data_type => 'character varying',
            default_value => undef,
            is_nullable => 0,
            size => 40,
        },
        login => {
            data_type => 'character varying',
            default_value => undef,
            is_nullable => 0,
            size => 20,
        },
        active => {
            data_type => 'boolean',
            default_value => 'true',
            is_nullable => 0,
            size => 1,
        },
    );
    __PACKAGE__->set_primary_key('id');
    __PACKAGE__->add_unique_constraint(person_login_key => ['login']);
    __PACKAGE__->add_unique_constraint(person_pkey => ['id']);
    # __PACKAGE__->has_many(
    #     person_roles => 'DemoApp::Schema::Result::PersonRole',
    #     { 'foreign.person' => 'self.id' },
    # );
    # 
    # __PACKAGE__->many_to_many('roles', 'person_roles', 'role');
    
    package Schema;
    use base 'DBIx::Class::Schema';
    Schema->register_class(Person => 'Schema::Result::Person');
}

exit;

# bring FormBuilder into our game
DBIx::Class->load_components('FormFuBuilder');

# build a resultset
my $schema = Schema->clone();

my $resultset = $schema->resultset('Schema::Result::Person');

my $form;
lives_ok { $form = $resultset->generate_form_fu() } 
         'form construction 1 OK';

is_deeply($form,
          { elements => [{
                           name => 'id',
                           type => 'Hidden'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'name',
                           filters => [],
                           type => 'Text',
                           label => 'Name'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'login',
                           filters => [],
                           type => 'Text',
                           label => 'Login'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'active',
                           filters => [],
                           type => 'Text',
                           label => 'Active'
                         }],
            attributes => {},
          }, 'form structure 1 OK');

# add an indicator
lives_ok { $form = $resultset->generate_form_fu({indicator => 'Save'}) } 
         'form construction 2 OK';

is_deeply($form,
          { indicator => 'Save',
            elements => [{
                           name => 'id',
                           type => 'Hidden'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'name',
                           filters => [],
                           type => 'Text',
                           label => 'Name'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'login',
                           filters => [],
                           type => 'Text',
                           label => 'Login'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'active',
                           filters => [],
                           type => 'Text',
                           label => 'Active'
                         },
                         {
                           type => 'Submit',
                           name => 'Save',
                           value => 'Save',
                           label => ' ',
                         }],
            attributes => {},
          }, 'form structure 2 OK');

# set some field-specific defaults
Schema::Result::Person->form_fu_extra(name => {
    label => 'The Name',
    filter => 'TrimEdges',
});
lives_ok { $form = $resultset->generate_form_fu() } 
         'form construction 3 OK';

is_deeply($form,
          { elements => [{
                           name => 'id',
                           type => 'Hidden'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'name',
                           filters => [ { type => 'TrimEdges'} ],
                           type => 'Text',
                           label => 'The Name'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'login',
                           filters => [],
                           type => 'Text',
                           label => 'Login'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'active',
                           filters => [],
                           type => 'Text',
                           label => 'Active'
                         }],
            attributes => {},
          }, 'form structure 3 OK');

# add a type modifier
Schema::Result::Person->form_fu_type_default(boolean => {
    type => 'Checkbox',
    value => 1,
    -constraint => 'Required',
});

lives_ok { $form = $resultset->generate_form_fu() } 
         'form construction 4 OK';

is_deeply($form,
          { elements => [{
                           name => 'id',
                           type => 'Hidden'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'name',
                           filters => [ { type => 'TrimEdges'} ],
                           type => 'Text',
                           label => 'The Name'
                         },
                         { 
                           constraints => [ { type => 'Required' } ],
                           name => 'login',
                           filters => [],
                           type => 'Text',
                           label => 'Login'
                         },
                         { 
                           constraints => [],
                           name => 'active',
                           filters => [],
                           type => 'Checkbox',
                           value => 1,
                           label => 'Active'
                         }],
            attributes => {},
          }, 'form structure 4 OK');
