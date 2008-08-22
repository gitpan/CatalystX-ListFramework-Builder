package CatalystX::ListFramework::Builder::Controller::Root;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Controller';

sub base : Chained PathPart('') CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash->{current_view} = 'LFB::TT';
    $c->stash->{version} = $CatalystX::ListFramework::Builder::VERSION;
    # this is a no-op, for making relocateable apps
}

sub no_table : Chained('base') PathPart('') Args(0) {
    my ($self, $c) = @_;
    $c->forward('LFB::Metadata');
    $c->detach('err_message');
}

sub table : Chained('base') PathPart('') CaptureArgs(1) {
    my ($self, $c, $table) = @_;
    $c->stash->{table} = $table;

    $c->forward('LFB::Metadata');
    $c->detach('err_message') if !defined $c->stash->{lf}->{model};
}

sub main : Chained('table') PathPart('') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'list.tt';
    $c->stash->{title} = $c->stash->{lf}->{main}->{title}
        .' List - powered by LFB v'. $c->stash->{version};
}

sub err_message : Private {
    my ($self, $c) = @_;
    $c->stash->{template} = 'tables.tt';
    $c->stash->{title} = 'Powered by LFB v'. $c->stash->{version};
}

sub helloworld : Chained('base') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = 'helloworld.tt';
}

sub end : ActionClass('RenderView') {}

1;
__END__
