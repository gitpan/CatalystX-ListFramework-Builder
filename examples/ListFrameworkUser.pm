package ListFrameworkUser;
use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);

# you probably want to change the path to this file
__PACKAGE__->config( 'Plugin::ConfigLoader' => { file => 'config.yml' } );

__PACKAGE__->setup;
1;
