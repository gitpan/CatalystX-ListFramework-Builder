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
    $c->detach('err_message') if !defined $c->stash->{lf};
    $c->stash->{version} = $CatalystX::ListFramework::Builder::VERSION;
    $c->stash->{template} = 'list-and-search.tt';
    $c->stash->{title} = $c->stash->{lf}->{main}->{title}
        .' List - powered by LFB v'. $c->stash->{version};
    $c->detach('TT');
}

sub end :Private {
    my ($self, $c) = @_;
    return if $c->res->output or ($c->res->status == 304);
    $c->detach('JSON');
}

sub err_message :Private {
    my ($self, $c) = @_;
    $c->res->output('Missing or unrecognized table name!');
}

sub helloworld :Path('/helloworld') {
    my ($self, $c) = @_;
    $c->res->output('Hello, world!');
}

1;
__END__
