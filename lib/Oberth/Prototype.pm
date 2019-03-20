use strict;
use warnings;
package Oberth::Prototype;
# ABSTRACT: Command line base for oberthian

use Env qw(@PATH);
use Config;

use Oberth::Prototype::FindOberthPrototype;

use constant OP_DIR => Oberth::Prototype::FindOberthPrototype->get_oberth_prototype_path_via_bin;
use constant BUILD_TOOLS_DIR => File::Spec->catfile( OP_DIR , qw(extlib));

use constant BIN_DIRS => [
	'bin'
];
use constant PERL_LIB_DIRS => [
	File::Spec->catfile(qw(lib perl5)),
	File::Spec->catfile(qw(lib perl5), $Config::Config{archname}),
];

BEGIN {
	require File::Glob;
	our @VENDOR_LIB = File::Glob::bsd_glob( OP_DIR . "/vendor/*/lib");
	unshift @INC, @VENDOR_LIB;

	my $lib_dir = BUILD_TOOLS_DIR;
	unshift @INC,      File::Spec->catfile( $lib_dir, $_ ) for @{ (PERL_LIB_DIRS) };
	unshift @PATH,     File::Spec->catfile( $lib_dir, $_ ) for @{ (BIN_DIRS) };
}

use Mu;
use CLI::Osprey;

use ShellQuote::Any;
use File::Path qw(make_path);
use File::Which;

use Oberth::Manoeuvre::Common::Setup;

use Oberth::Prototype::Config;
use Oberth::Prototype::Repo;

use Oberth::Prototype::System::Debian;
use Oberth::Prototype::System::MacOSHomebrew;
use Oberth::Prototype::System::AppVeyor;

has repo_url_to_repo => (
	is => 'ro',
	default => sub { +{} },
);

lazy platform => method() {
		my @opt = ( config => $self->config );
		my $system;
		if(  $^O eq 'darwin' && which('brew') ) {
			$system = Oberth::Prototype::System::MacOSHomebrew->new( @opt );
		} elsif( $^O eq 'MSWin32' ) {
			$system = Oberth::Prototype::System::AppVeyor->new( @opt );
		} else {
			$system = Oberth::Prototype::System::Debian->new( @opt );
		}
};

has config => (
	is => 'ro',
	default => sub {
		Oberth::Prototype::Config->new();
	},
);

lazy repo => method() {
	my $repo = $self->repo_for_directory('.');
};

method _env() {
	my $test_data_repo_dir = $self->clone_git("https://github.com/project-renard/test-data.git");
	$ENV{RENARD_TEST_DATA_PATH} = $test_data_repo_dir;
}

method install() {
	$self->_env;

	$self->platform->_install;

	unless( $self->config->cpan_global_install ) {
		$self->platform->build_perl->script(
			qw(cpm install -L), $self->config->lib_dir, qw(local::lib)
		)
	}

	$self->platform->_pre_run;

	my $repo = $self->repo;

	$self->platform->install_packages($repo);

	$self->install_recursively($repo, main => 1, native => 1);
	$self->install_recursively($repo, main => 1, native => 0 );

	$repo->setup_build;
}

method test() {
	$self->_env;

	$self->platform->_pre_run;

	my $repo = $self->repo;
	$self->test_repo($repo);
}

method run() {
	$self->install;
}

subcommand 'test' => method() {
	$self->test;
};


method install_recursively($repo, :$main = 0, :$native = 0) {
	my @deps = $self->fetch_git($repo);
	for my $dep (@deps) {
		$self->install_recursively( $dep, native => $native  );
	}
	if( !$main ) {
		$self->install_repo($repo, native => $native );
	}
}

method install_repo($repo, :$native = 0 ) {
	return if -f $repo->directory->child('installed');

	my $exit = 0;

	if( $native ) {
		$self->platform->install_packages($repo);
	} else {
		$repo->setup_build;
		$exit = $repo->install;

		$repo->directory->child('installed')->touch;
	}

	return $exit;
}

method test_repo($repo) {
	$repo->run_test;
}

method fetch_git($repo) {
	my @repos;

	my $deps = $repo->cpanfile_git_data;

	my @keys = keys %$deps;

	my $urls = $self->repo_url_to_repo;

	for my $module_name (@keys) {
		my $repos = $deps->{$module_name};

		my $repo;
		if( exists $urls->{ $repos->{git} } ) {
			$repo = $urls->{ $repos->{git} };
		} else {
			my $path = $self->clone_git( $repos->{git}, $repos->{branch} );

			$repo = $self->repo_for_directory($path);
			$urls->{ $repos->{git} } = $repo;
		}

		push @repos, $repo;
	}

	@repos;
}

method clone_git($url, $branch = 'master') {
	$branch = 'master' unless $branch;

	say STDERR "Cloning $url @ [branch: $branch]";
	my ($parts) = $url =~ m,^https?://[^/]+/(.+?)(?:\.git)?$,;
	my $path = File::Spec->rel2abs(File::Spec->catfile($self->config->external_dir, split(m|/|, $parts)));

	unless( -d $path ) {
		system(qw(git clone),
			qw(-b), $branch,
			$url,
			$path) == 0
		or die "Could not clone $url @ $branch";
	}

	return $path;

}

method repo_for_directory($directory) {
	my $repo = Oberth::Prototype::Repo->new(
		directory => $directory,
		config => $self->config,
		platform => $self->platform,
	);

	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::DistZilla');
	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::CpanfileGit');
	Moo::Role->apply_roles_to_object( $repo, 'Oberth::Prototype::Repo::Role::DevopsYaml');
}


1;
