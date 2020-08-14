use Modern::Perl;
package Orbital::Launch::System::MacOSHomebrew;
# ABSTRACT: macOS with homebrew

use Mu;
use Orbital::Transfer::Common::Setup;
use IPC::System::Simple ();
use Object::Util magic => 0;

use Orbital::Launch::EnvironmentVariables;
use Orbital::Launch::Runner::Default;
use aliased 'Orbital::Launch::Runnable';

lazy homebrew_prefix => method() {
	path("/usr/local");
};

lazy environment => method() {
	my $env = Orbital::Launch::EnvironmentVariables
		->new;

	# Set up Homebrew bin path
	$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('bin')->stringify ]  );

	# Set up for OpenSSL (linking and utilities)
	$env->prepend_path_list( 'PKG_CONFIG_PATH', [ $self->homebrew_prefix->child('opt/openssl/lib/pkgconfig')->stringify ]  );
	$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('opt/openssl/bin')->stringify ]  );

	# Set up for libffi linking
	$env->prepend_path_list( 'PKG_CONFIG_PATH', [ $self->homebrew_prefix->child('opt/libffi/lib/pkgconfig')->stringify ]  );

	# Add Homebrew gettext utilities to path
	$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('opt/gettext/bin')->stringify ]  );

	$env->set_string('ARCHFLAGS', '-arch x86_64' );

	$env;
};

method _pre_run() {

}

method _install() {
	say STDERR "Updating homebrew";
	$self->runner->$_try( system =>
		Runnable->new(
			command => [ qw(brew update) ]
		)
	);

	# Remove old Python package
	$self->runner->$_try( system =>
		Runnable->new(
			command => [ qw(brew unlink python@2) ]
		)
	);

	# Set up for X11 support
	say STDERR "Installing xquartz homebrew cask for X11 support";
	$self->runner->$_try( system =>
		Runnable->new(
			command => $_
		)
	) for (
		[ qw(brew tap Caskroom/cask) ],
		[ qw(brew install Caskroom/cask/xquartz) ]
	);

	# Set up for pkg-config
	$self->runner->$_try( system =>
		Runnable->new(
			command => [ qw(brew install pkg-config) ]
		)
	);

	# Set up for OpenSSL (linking and utilities)
	$self->runner->$_try( system =>
		Runnable->new(
			command => [ qw(brew install openssl) ]
		)
	);
}

method install_packages($repo) {
	my @packages = @{ $repo->homebrew_get_packages };
	say STDERR "Installing repo native deps";
	if( @packages ) {
		# Skip font cache generation (for fontconfig):
		# <https://github.com/Homebrew/homebrew-core/pull/10947#issuecomment-285946088>
		my $has_fontconfig_dep = eval {
			use autodie qw(:system);
			system( qq{brew deps --union @packages | grep ^fontconfig\$ && brew install --force-bottle --build-bottle fontconfig} );
		};

		my @deps_to_install = grep {
			my $dep = $_;
			eval {
				use autodie qw(:system);
				system( qq{brew ls @packages >/dev/null 2>&1} );
			};
			$@ ? 1 : 0;
		} @packages;
		say STDERR "Native deps to install: @deps_to_install";

		if(@deps_to_install) {
			system( qq{brew install @deps_to_install || true} );
			system( qq{brew install @packages || true} );
		}
	}
}

with qw(
	Orbital::Launch::System::Role::Config
	Orbital::Launch::System::Role::DefaultRunner
	Orbital::Launch::System::Role::PerlPathCurrent
	Orbital::Launch::System::Role::Perl
);

1;
