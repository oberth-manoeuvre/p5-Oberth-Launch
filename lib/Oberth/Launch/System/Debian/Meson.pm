use Modern::Perl;
package Oberth::Launch::System::Debian::Meson;
# ABSTRACT: Install and setup meson build system

use Mu;
use Oberth::Manoeuvre::Common::Setup;
use Oberth::Launch::EnvironmentVariables;
use aliased 'Oberth::Launch::Runnable';
use Object::Util;

has platform => (
	is => 'ro',
	required => 1,
);

has runner => (
	is => 'ro',
	required => 1,
);

method environment() {
	my $py_user_base_bin = $self->runner->capture(
		Runnable->new(
			command => [ qw(python3 -c), "import site, os; print(os.path.join(site.USER_BASE, 'bin'))" ],
			environment => $self->platform->environment
		)
	);
	chomp $py_user_base_bin;

	my $py_user_site_pypath = $self->runner->capture(
		Runnable->new(
			command => [ qw(python3 -c), "import site; print(site.USER_SITE)" ],
			environment => $self->platform->environment
		)
	);
	chomp $py_user_site_pypath;
	Oberth::Launch::EnvironmentVariables
		->new
		->$_tap( 'prepend_path_list', 'PATH', [ $py_user_base_bin ] )
		->$_tap( 'prepend_path_list', 'PYTHONPATH', [ $py_user_site_pypath ] )
}

method setup() {
	if( $> != 0 ) {
		warn "Not installing meson";
	} else {
		$self->runner->system(
			Runnable->new(
				command => $_,
				environment => $self->environment,
			)
		) for(
			[ qw(apt-get install -y --no-install-recommends python3-pip) ],
			[ qw(pip3 install --user -U setuptools wheel) ],
			[ qw(pip3 install --user -U meson) ],
		);
	}
}

1;
