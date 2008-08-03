package ListFrameworkUser;
use base 'CatalystX::ListFramework::Builder';

# you probably want to change the path to this file
__PACKAGE__->build_listframework('config.yml');

1;
