package CatalystX::ListFramework::Builder::Controller::Image;

use strict;
use warnings FATAL => 'all';

use base 'Catalyst::Controller';

use File::stat;
use File::Basename;

# erm, this is a bit sick. it's basically Catalyst::Plugin::Static on the
# cheap. there are a couple of nice icons we want to make sure the users have
# but it'd be too much hassle to ask them to install, so we bundle them.
#
sub image : Chained('/lfb/root/base') Args(1) {
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
        $c->res->status(200);
        return 1;
    }

    $c->log->debug(qq/Failed to serve file "$path"/) if $c->debug;
    $c->res->status(404);
    return 0;
}

1;
__END__
