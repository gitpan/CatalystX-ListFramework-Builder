package CatalystX::ListFramework::Builder::View::TT;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::View::TT';
use File::Basename;

# the templates are squirreled away in ../templates
(my $pkg_path = __PACKAGE__) =~ s{::}{/}g;
my (undef, $directory, undef) = fileparse(
    $INC{ $pkg_path .'.pm' }
);

__PACKAGE__->config(
    INCLUDE_PATH => "$directory../templates",
    COMPILE_DIR => "/tmp/template_cache",
    # STASH => Template::Stash::XS->new,
    TEMPLATE_EXTENSION => '.tt',
    CATALYST_VAR => 'c',
    WRAPPER => 'wrapper.tt',
);

1;
__END__
