package CatalystX::ListFramework::Builder;

use strict;
use warnings FATAL => 'all';

use Class::C3;
use Devel::InnerPackage qw/list_packages/;

our $VERSION = 0.25;

sub setup_components {
    my $class = shift;
    $class->next::method(@_);

    # these are the boilerplate Catalyst components for ListFramework
    my @packages = qw(
        Controller::Root
        Controller::Image
        Controller::AJAX
        Model::DBIC
        Model::Metadata
        View::JSON
        View::TT
    );

    foreach my $orig (@packages) {
        (my $p = $orig) =~ s/::/::LFB::/;
        my $comp = "${class}::${p}";

        # require will shortcircuit and return true if the component is
        # already loaded
        unless (eval "package $class; require $comp;") {

            # make a component on the fly in the App namespace
            eval qq(
                package $comp;
                use base qw/CatalystX::ListFramework::Builder::${orig}/;
                1;
            );
            die $@ if $@;

            # inject entry to %INC so Perl knows this component is loaded
            # this is just for politeness and does not aid Catalyst
            (my $file = "$comp.pm") =~ s{::}{/}g;
            $INC{$file} = 'loaded';

            #  add newly created components to catalyst
            #  must set up component and -then- call list_packages on it
            $class->components->{$comp} = $class->setup_component($comp);
            for my $m (list_packages($comp)) {
                $class->components->{$m} = $class->setup_component($m);
            }
        }
    }

    return 1;
}

1;

__END__

=head1 NAME

CatalystX::ListFramework::Builder - Instant AJAX web front-end for
DBIx::Class, using Catalyst

=head1 VERSION

This document refers to version 0.25 of CatalystX::ListFramework::Builder

=head1 WARNING

This is an I<ALPHA RELEASE>. I'd really appreciate any bug reports; you can
use the CPAN RT bug tracking system, or email me (Oliver) directly at the
address at the bottom of this page. Please also be aware that the
configuration file content has changed from previous releases of the module.

=head1 PURPOSE

You have a database schema available through L<DBIx::Class>, and wish to have
a basic web interface supporting Create, Retrieve, Update, Delete and Search,
with little effort.

This module, with only a few lines of configuration, is able to create such
interfaces on the fly. They are a bit whizzy and all Web 2.0-ish.

=head1 SYNOPSIS

A configuration file somewhere on your system:

 # [listframeworkuser.conf] in Config::General format
 
 extjs2   /javascript/extjs-2
 
 <Model::LFB::DBIC>
     schema_class   My::Database::Schema
     connect_info   dbi:Pg:dbname=mydbname;host=mydbhost.example.com;
     connect_info   username
     connect_info   password
     <connect_info>
         AutoCommit   1
     </connect_info>
 </Model::LFB::DBIC>

And in the CGI area of your web server:

 package ListFrameworkUser;
 use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);
 
 __PACKAGE__->setup;
 1;

Now going to the CGI area's URL will display a list of the tables in your
database. Each item is a link to the web interface for that table.

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
     'make_schema_at("DBIC::Database::Foo::Schema", { relationships => 1 }, \
     ["dbi:Pg:dbname=foodb;host=mydbhost.example.com","user","pass" ])'

This will create a directory (such as C<DBIC>) which you need to move into
your Perl Include path.

=head2 C<DBIx::Class> helpers

When the web interface wants to display a column which references another
table, you can make things look much better by adding a custom render method
to your C<DBIx::Class> Result Sources (i.e. the class files for each table).

First, the application will look for a method called C<display_name> and use
that. Here is an example which could be added to your Result Source classes
below the line which reads C<DO NOT MODIFY THIS OR ANYTHING ABOVE>, and in
this case returns the data from the C<title> column:

 sub display_name {
     my $self = shift;
     return $self->title || '';
 }

Failing the existence of a C<display_name> method, the application attempts to
stringify the row object. Using stringification is not recommended, although
some people like it. Here is an example of a stringification handler:

 use overload '""' => sub {
     my $self = shift;
     return $self->title || '';
 }, fallback => 1;

If all else fails the application prints the best hint it can to describe the
foreign row. This is something approximating the name of the foreign table,
the names of the primary keys, and associated values. It's better than
stringifying the object the way Perl does, anyway.

One other very important tip: for those columns where your database uses an
auto-incremented value, add the C<< is_auto_increment => 1, >> option to the
relevant hash in add_columns(). This will let the application know you don't
need to supply a value for new or updated records. The interface will look
much better as a result.

Finally, buried within one of the modules in this application are some
filters, which are applied to data of certain types as it enters or leaves the
database. If you find a particular data type is not being rendered correctly,
please drop the author a line at the email address below, explaining what
you'd like to see instead.

=head2 Download and install ExtJS

You'll need to download the ExtJS Javascript Library (version 2.2+
recommended), from this web page:
L<http://extjs.com/products/extjs/download.php>.

Install it to your web server in a location that it is able to serve as static
content. Make a note of the path used in a URL to retrieve this content, as it
will be needed in the application configuration file, below.

=head2 Application configuration file

Create the application configuration file, an example of which is below:

 extjs2   /javascript/extjs-2
 <Model::LFB::DBIC>
     schema_class   My::Database::Schema
     connect_info   dbi:Pg:dbname=mydbname;host=mydbhost.example.com;
     connect_info   username
     connect_info   password
     <connect_info>
         AutoCommit   1
     </connect_info>
 </Model::LFB::DBIC>

The C<Model::LFB::DBIC> section must look (and be named) exactly like that
above, except you should of course change the C<schema_class> value and the
values within C<connect_info>.

The application needs to know where your copy of ExtJS is, on the web server.
Use the C<extjs2> option as shown above to specify the URL path to the
libraries. This will be used in the templates in some way like this:

 <script type="text/javascript" src="[% c.extjs2 %]/ext-all.js" />

=head3 Relocating LFB to another URL path

If you want to use this application as a plugin with another Catalyst system,
it should work fine, but you probably want to serve pages under a different
path on your web site. To do that, add the following to your configuration
file:

 <Controller::LFB::Root>
     <action>
         <base>
             PathPart   admin
         </base>
     </action>
 </Controller::LFB::Root>

In the above example, the path C<...E<sol>adminE<sol>> will contain the LFB
application, and all generated links in LFB will also make use of that path.
Remember this is added to the C<base> of your Cataylst application which,
depending on your web server configuration, might also have a leading path.

=head2 Catalyst application

The final step is to write a very small file which allows this module to
bootstrap a Catalyst application around your database. Locate on your web
server the area where Perl content is executed, and create a file as below:

 package ListFrameworkUser;
 use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);
 
 __PACKAGE__->setup;
 1;

Let your web server know that this file is to be executed for any request
which comes to its location.

If necessary, you'll need to let the C<ConfigLoader> plugin know of the
whereabouts of your application configuration file. See the
L<Catalyst::Plugin::ConfigLoader> documentation for more details, although
here is a brief example of the change required:

 __PACKAGE__->config( 'Plugin::ConfigLoader' => { file => 'myapp.conf' } );
 __PACKAGE__->setup;

=head2 Accessing the application from your browser

Presumably the location of the Catalyst application created in the previous
section maps to a particular URL path. Follow this path with the name of a
table in the database, and you should be presented with a table of data. If
you omit the table name, then the application prompts you with a list of the
available tables.

=head1 EXAMPLES

There is an C<examples> directory included with this distribution which
includes the files necessary to set up a small demo application with SQLite3.

=head1 LIMITATIONS

=over 4

=item Single column primary key

There's no support for multiple column primary keys (composite/compound
keys). This has saved a lot of time in development because it greatly
simplifies the L<Catalyst> and L<DBIx::Class> code.

=item No two columns in a given table may have the same FK constraint

If you have two columns which both have foreign key constraints to the same
table, it's very likely LFB will not work. Again this is a simplification
which speeded the initial development.

=back

For the issues above, if you're desperate that the feature be implemented
soon, please drop me a line at the address below, because you might be able to
buy some of my time for the development.

=head1 REQUIREMENTS

=over 4

=item *

ExtJS Javascript Library (version 2.2+ recommended), from L<http://extjs.com>.

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

=back

=head1 SEE ALSO

L<CatalystX::ListFramework> is similar but has no dependency on Javascript
(though it can use it for fancy auto-complete searches), and it also allows
you to control which columns are rendered in the display.

=head1 ACKNOWLEDGEMENTS

Without the initial work on C<CatalystX::ListFramework> by Andrew Payne and
Peter Edwards this package would not exist. If you are looking for something
like this module but without the dependency on Javascript, please do check
out L<CatalystX::ListFramework>.

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

=head1 COPYRIGHT & LICENSE

Bundled images are Copyright (c) 2006 Mark James, and are from
L<http://www.famfamfam.com/lab/icons/silk/>.

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

