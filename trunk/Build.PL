use Module::Build::Compat;

my $build = Module::Build->new(
    module_name => 'DBIx::Class::FormFuBuilder',
    license => 'perl',
    dist_author => 'Wolfgang Kinkeldei <wki@cpan.org>',
    dist_abstract => 'generate HTML::FormFu forms from a resultset',
    requires => {
        'perl'                  => '5.8.8',
        'Catalyst::Runtime'     => '5.80',
        'Test::Builder'         => '0.86',
        'Test::Builder::Tester' => '1.18',
        'Test::More'            => '0.86',
        'Test::Harness'         => '3.14',
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    # sign => 1,
);
$build->create_build_script;
Module::Build::Compat->create_makefile_pl(traditional => $build);
