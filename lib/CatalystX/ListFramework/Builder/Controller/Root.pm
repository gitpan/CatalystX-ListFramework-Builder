package CatalystX::ListFramework::Builder::Controller::Root;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Controller';
use CatalystX::ListFramework::Core;

use File::stat;
use File::Basename;

# Set the actions in this controller to be registered with no prefix
__PACKAGE__->config->{namespace} = '';

sub helloworld :Path('/helloworld') {
    my ( $self, $c ) = @_;
    $c->res->output('Hello world!');
}

# TODO: CatalystX::ListFramework->new can be in an auto() thing

sub default :Path {
    my ($self, $c, $kind) = @_;
    my $lf = CatalystX::ListFramework::Core->new($kind, $c);
    $c->stash->{name}     = $lf->{name};
    $c->stash->{formdef}  = $lf->{formdef};
    $c->stash->{template} = 'list-and-search.tt';
    $c->view('TT')->process($c);
}

sub jlist :Path('/jlist') {
    my ($self, $c, $kind) = @_;
    my $lf = CatalystX::ListFramework::Core->new($kind, $c)->stash_json_list();
    $c->view('JSON')->process($c);
}

sub jget_stringified :Path('/jget_stringified') {
    my ($self, $c, $kind) = @_;
    my $lf = CatalystX::ListFramework::Core->new($kind, $c)->jget_stringified();
    $c->view('JSON')->process($c);
}

sub jupdate :Path('/jupdate') {
    my ($self, $c, $kind) = @_;
    my $lf = CatalystX::ListFramework::Core->new($kind, $c)->jupdate_from_query();
    $c->view('JSON')->process($c);
}

sub jdelete :Path('/jdelete') {
    my ($self, $c, $kind) = @_;
    my $lf = CatalystX::ListFramework::Core->new($kind, $c)->jdelete();
    $c->view('JSON')->process($c);
}

# erm, this is a bit sick. it's basically Catalyst::Plugin::Static on the
# cheap. there are a couple of nice icons we want to make sure the users have
# but it'd be too much hassle to ask them to install, so we bundle them.
#
sub image :Path('/image') {
    my ($self, $c, $file) = @_;

    (my $pkg_path = __PACKAGE__) =~ s{::}{/}g;
    my (undef, $directory, undef) = fileparse(
        $INC{ $pkg_path .'.pm' }
    );

    my $path = "$directory../images/$file";

    if ( ($file =~ m/^\w+\.png$/i) and (-f $path) ) {
        my $stat = stat($path);

        if ( $c->req->headers->header('If-Modified-Since') ) {

            if ( $c->req->headers->if_modified_since == $stat->mtime ) {
                $c->res->status(304); # Not Modified
                $c->res->headers->remove_content_headers;
                return 1;
            }
        }

        my $content = do { local (@ARGV, $/) = $path; <> };
        $c->res->headers->content_type('image/png');
        $c->res->headers->content_length( $stat->size );
        $c->res->headers->last_modified( $stat->mtime );
        $c->res->output($content);
        if ( $c->config->{static}->{no_logs} && $c->log->can('abort') ) {
           $c->log->abort( 1 );
    }
        $c->log->debug(qq{Serving file "$path" as "image/png"}) if $c->debug;
        return 1;
    }

    $c->log->debug(qq/Failed to serve file "$path"/) if $c->debug;
    $c->res->status(404);
    return 0;
}

1;
__END__
