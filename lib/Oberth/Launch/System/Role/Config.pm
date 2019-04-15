use Modern::Perl;
package Oberth::Launch::System::Role::Config;
# ABSTRACT: Has config

use Mu::Role;
use Oberth::Manoeuvre::Common::Setup;

has config => (
	is => 'ro',
	required => 1,
);

1;
