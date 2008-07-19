package CatalystX::ListFramework::Builder;

use strict;
use warnings FATAL => 'all';

our $VERSION = 0.07;

sub build_listframework {
    my ($class, $config) = @_;
    my $caller = scalar caller;

    # these are the boilerplate Catalyst components for ListFramework
    my @packages = qw(
        Controller::Root
        Model::DBIC
        View::JSON
        View::TT
    );

    foreach my $p (@packages) {
        my $component = "${caller}::${p}";

        # require will shortcircuit and return true if the component is
        # already loaded
        if (! eval "package $caller; require $component;") {
            # make a component on the fly in the App namespace
            eval "package $component;
                  use base qw(CatalystX::ListFramework::Builder::${p}); 1;
            ";
            die $@ if $@;

            # inject entry to %INC so Perl knows this component is loaded
            (my $file = "$component.pm") =~ s{::}{/}g;
            $INC{$file} = 'loaded';
        }
    }

    # now load the main catalyst app, passing through our config file
    # this is done in the caller's namespace
    eval "package ${caller};
          use base 'CatalystX::ListFramework::Builder::Base';
          ${caller}->config( file => '$config' );
          ${caller}->setup;
          1;
    ";
    die $@ if $@;

    return 1;
}

1;

__END__

=head1 NAME

CatalystX::ListFramework::Builder - Instant AJAX web front-end for DBIx::Class, using Catalyst

=head1 VERSION

This document refers to version 0.07 of CatalystX::ListFramework::Builder

=head1 WARNING

This is an I<ALPHA RELEASE>. I'd really appreciate any bug reports; you can
use the CPAN RT bug tracking system, or email me (Oliver) directly at the
address at the bottom of this page.

=head1 PURPOSE

You have a database schema available through L<DBIx::Class>, and wish to have
a basic web interface supporting Create, Retrieve, Update, Delete and Search,
with little effort.

This module, with only a few lines of configuration, is able to create such
interfaces on the fly. They are a bit whizzy and all Web 2.0-ish.

=head1 ACKNOWLEDGEMENTS

Without the initial work on C<CatalystX::ListFramework> by Andrew Payne and
Peter Edwards this package would not exist. If you are looking for something
like this module but without the dependency on Javascript, please do check
out L<CatalystX::ListFramework>.

=head1 SYNOPSIS

A configuration file somewhere on your system:

 --- #YAML:1.0
 # (/path/to/listframeworkuser/config.yml)
 base: "http://mywebserver.example.com"
 javascript: "/javascript/extjs-2"
 
 Model::DBIC:
   schema_class: My::Database::Schema
   connect_info:
     - 'dbi:Pg:dbname=mydbname;host=mydbhost.example.com;'
     - 'username'
     - 'password'
     - { AutoCommit: 1 }

And in the cgi-bin area of your web server:

 package ListFrameworkUser;
 use base 'CatalystX::ListFramework::Builder';
 
 __PACKAGE__->build_listframework('/path/to/listframeworkuser/config.yml');
 
 1;

Now going to C<http://mywebserver.example.com/cgi-bin/tablename> will render
the web frontend for a table in your database. This can be much refined; see
L</USAGE>, below.

=head1 DESCRIPTION

This module contains an application which will automatically construct a web
interface for a database on the fly. The web interface supports Create,
Retrieve, Update, Delete and Search operations.

The interface is not written to static files on your system, and uses AJAX to
act upon the database without reloading your web page (much like other
Web 2.0 appliactions, for example Google Mail).

The goals of the system are to require as little repetition of effort on your
part as possible - the DRY principle (Don't Repeat Yourself). Almost all the
information required is retrieved from the L<DBIx::Class> ORM frontend to your
database, which it is expected that you have already set up (although see
L</USAGE>, below). This means that any change in database schema ought to be
reflected immediately in the web interface after a page refresh.

=head1 USAGE

=head2 C<DBIx::Class> setup

You will need C<DBIx::Class> schema to be created and installed on your
system. The recommended way to do this quickly is to use the excellent
L<DBIx::Class::Schema::Loader> module which connects to your database and
writes C<DBIx::Class> Perl modules for it.

Pick a suitable namespace for your schema, which is not related to this
application. For example C<DBIC::Database::Foo::Schema> for the C<Foo>
database. Then use the following command-line incantation:

 perl -MDBIx::Class::Schema::Loader=make_schema_at,dump_to_dir:. -e \
     make_schema_at("DBIC::Database::Foo::Schema", { relationships => 1 }, \
     ["dbi:Pg:dbname=foodb;host=mydbhost.example.com","user","pass" ])

This will create a directory (such as C<DBIC>) which you need to move into
your Perl Include path.

=head2 C<DBIx::Class> helpers

You I<really> should add some stringification to these C<DBIx::Class> schema
otherwise the web interface will contain strange data. Add a stringify routine
to the bottom of each schema file; something like this:

 use overload '""' => sub {
     my $self = shift;
     return $self->title;
 }, fallback => 1;

In this example the row stringifies to the C<title> column but you can of
course return anything you wish.

Also, for those columns where your database uses an auto-incremented value,
add the C<< is_auto_increment => 1, >> option to the relevant hash in
add_columns(). This will let the application know you don't need to supply a
value for new or updated records.

=head2 Download and install ExtJS

You'll need to download the ExtJS Javascript Library (version 2.1 or later)
from this web page: L<http://extjs.com/products/extjs/download.php>.

Install it to your web server in a location that it is able to serve as static
content. Make a note of the path used in a URL to retrieve this content, as it
will be needed in the application configuration file, below.

=head2 Application configuration file

Create the application configuration file, an example of which is below:

 --- #YAML:1.0
 base: "http://mywebserver.example.com"
 javascript: "/javascript/extjs-2"
 
 Model::DBIC:
   schema_class: My::Database::Schema
   connect_info:
     - 'dbi:Pg:dbname=mydbname;host=mydbhost.example.com;'
     - 'username'
     - 'password'
     - { AutoCommit: 1 }

The application needs to know where your copy of ExtJS (version 2.1 or later)
is, on the web server. Use the C<javascript> option as shown above to specify
the URL path to the libraries. This will be used in the templates in some way
like this:

 <script type="text/javascript" src="[% c.base %][% c.javascript %]/ext-all.js" />

The C<Model::DBIC> section must look (and be named) exactly like that above,
except you should of course change the C<schema_class> value and the values
within C<connect_info>.

=head2 Catalyst application

The final step is to write a very small file which allows this module to
bootstrap a Catalyst application around your database. Locate on your web
server the area where Perl content is executed, and create a file as below:

 package ListFrameworkUser;
 use base 'CatalystX::ListFramework::Builder';
 
 __PACKAGE__->build_listframework('/path/to/listframeworkuser/config.yml');
 
 1;

Obviously, replace the path there with that of the configuration file you
created in the previous section. Let your web server know that this file is to
be executed for any request which comes to its location.

=head2 Accessing the application from your browser

Presumably the location of the Catalyst application created in the previous
section maps to a particular URL path. Follow this path with the name of a
table in the database, and you should be presented with a table of data.

=head1 REQUIREMENTS

=over 4

=item *

ExtJS Javascript Library version 2.1 or later, from L<http://extjs.com>.

=item *

Catalyst::Runtime >= 5.70

=item *

Catalyst::Model::DBIC::Schema

=item *

Catalyst::View::JSON

=item *

Catalyst::View::TT

=item *

Class::C3

=item *

Class::Data::Inheritable

=item *

List::MoreUtils

=back

=head1 SEE ALSO

L<CatalystX::ListFramework> is similar but has no dependency on Javascript
(though it can use it for fancy auto-complete searches), and it also allows
you to control which columns are rendered in the display.

=over 4

=item *

L<http://dev.catalyst.perl.org/new-wiki/crud>

=back

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

Much of the design of this system came from L<CatalystX::ListFramework>, by Andrew Payne and Peter Edwards.

=head1 COPYRIGHT & LICENSE

Bundled images are Copyright (c) 2006 Mark James, and are from L<http://www.famfamfam.com/lab/icons/silk/>.

The rest is Copyright (c) Oliver Gorwits 2008. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
St, Fifth Floor, Boston, MA 02110-1301 USA

=cut

