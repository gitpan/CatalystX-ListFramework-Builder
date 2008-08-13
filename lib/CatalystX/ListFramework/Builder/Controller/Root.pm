package CatalystX::ListFramework::Builder::Controller::Root;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Controller';

# Set the actions in this controller to be registered with no prefix
__PACKAGE__->config->{namespace} = '';

sub begin :Private {
    my ($self, $c, $table) = @_;
    $c->stash->{table} = $table;
    $c->forward('Metadata');
}

sub default :Private {
    my ($self, $c, $table) = @_;

    $c->stash->{version} = $CatalystX::ListFramework::Builder::VERSION;
    $c->detach('err_message') if !defined $c->stash->{lf}->{model};

    $c->stash->{template} = 'list-and-search.tt';
    $c->stash->{title} = $c->stash->{lf}->{main}->{title}
        .' List - powered by LFB v'. $c->stash->{version};
    $c->detach('TT');
}

sub end :Private {
    my ($self, $c) = @_;
    $c->detach('JSON') if $c->stash->{json_data};
}

sub err_message :Private {
    my ($self, $c) = @_;
    $c->stash->{template} = 'tables.tt';
    $c->stash->{title} = 'Powered by LFB v'. $c->stash->{version};
    $c->detach('TT');
}

sub helloworld :Path('/helloworld') {
    my ($self, $c) = @_;
    $c->res->output('Hello, world!');
}

1;
__END__
