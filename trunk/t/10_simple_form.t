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

# bring FormBuilder into our game
DBIx::Class->load_components('FormFuBuilder');

# build a resultset
my $schema = Schema->clone();

my $resultset = $schema->resultset('Person');

my $form;
lives_ok { my $form = $resultset->generate_form_fu() } 'form construction OK';

use Data::Dumper;
print STDERR Data::Dumper->Dump([$form], ['form']);
