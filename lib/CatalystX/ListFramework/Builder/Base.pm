package CatalystX::ListFramework::Builder::Base;

use strict;
use warnings FATAL => 'all';

use Catalyst::Runtime '5.70';
use Class::C3;

use Catalyst qw/ConfigLoader/;

our $VERSION = 1.00;

# override Catalyst's own component setup, because after the bootstrapping in
# Builder.pm Catalyst won't spot the components, so we set them up ourselves.
sub setup_components {
    my $self = shift;
 
    my @packages = qw(
        Controller::Root
        Model::DBIC
        View::JSON
        View::TT
    );
 
    # call Catalyst's own setup_components
    $self->next::method(@_);
 
    # now do similar work to Catalyst's setup_components
    foreach my $p (@packages) {
        my $component = "${self}::${p}";
        next if exists $self->components->{ $component };
 
        my $module  = $self->setup_component( $component );
        my %modules = (
            $component => $module,
            map {
                $_ => $self->setup_component( $_ ) 
            } Devel::InnerPackage::list_packages( $component )
        );   
 
        $self->components( {} ) if !defined $self->components;
        for my $key ( keys %modules ) {
            $self->components->{ $key } = $modules{ $key };
        }    
    }
}

1;
