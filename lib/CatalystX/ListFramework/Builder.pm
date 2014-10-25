package CatalystX::ListFramework::Builder;

use strict;
use warnings FATAL => 'all';

use MRO::Compat;
use Devel::InnerPackage qw/list_packages/;

our $VERSION = '0.42';
$VERSION = eval $VERSION; # numify for warning-free dev releases

sub setup_components {
    my $class = shift;
    $class->next::method(@_);

    # these are the boilerplate Catalyst components for ListFramework
    my @packages = qw(
        Controller::Root
        Controller::Static
        Controller::AJAX
        Model::Metadata
        View::JSON
        View::TT
    );

    # will auto-load other models, so this one is not -required-
    if (exists $class->config->{'Model::LFB::DBIC'}) {
        push @packages, 'Model::DBIC';
        my $p = 'Model::LFB::DBIC';

        # on the fly schema engineering
        if (!exists $class->config->{$p}->{schema_class}) {
            require DBIx::Class::Schema::Loader;
            die "Must have DBIx::Class::Schema::Loader version > 0.04005"
                if eval "$DBIx::Class::Schema::Loader::VERSION" <= 0.04005;

            DBIx::Class::Schema::Loader::make_schema_at(
                'LFB::Loader::Schema', {},
                $class->config->{$p}->{connect_info},
            );

            eval q{
                package # hide from pause
                    LFB::Loader::Schema;
                use base 'DBIx::Class::Schema';
                LFB::Loader::Schema->load_classes();
                1;
            };
            $INC{'LFB/Loader/Schema.pm'} = 'loaded';

            $class->config->{$p}->{schema_class} = 'LFB::Loader::Schema';
        }
    }

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

CatalystX::ListFramework::Builder - *** DEPRECATED *** please see Catalyst::Plugin::AutoCRUD

=head1 VERSION

This document refers to version 0.42 of CatalystX::ListFramework::Builder

=head1 WARNING

This module will work, but is B<no longer actively being developed>. The same
author has created L<Catalyst::Plugin::AutoCRUD> which should be almost a
drop-in replacement for you, and has even more yummy automagic goodness.

=head1 PURPOSE

You have a database, and wish to have a basic web interface supporting Create,
Retrieve, Update, Delete and Search, with little effort.

This module, with only a few lines of configuration, is able to create such
interfaces on the fly. They are a bit whizzy and all Web 2.0-ish.

=head1 SYNOPSIS

A configuration file somewhere on your system:

 # [listframeworkuser.conf] in Config::General format
 
 extjs2   /static/javascript/extjs-2
 
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

Almost all the information required by the application is retrieved from the
L<DBIx::Class> ORM frontend to your database, which it is expected that you
have already set up (although see L</USAGE>, below). This means that any
change in database schema ought to be reflected immediately in the web
interface after a page refresh.

=head1 USAGE

=head2 Pre-configuration

You'll need to download the ExtJS Javascript Library (version 2.2+
recommended), from this web page:
L<http://extjs.com/products/extjs/download.php>.

Install it to your web server in a location that it is able to serve as static
content. Make a note of the path used in a URL to retrieve this content, as it
will be needed in the application configuration file, below.

=head2 Scenario 1: Plugin to an existing Catalyst App

This mode is for when you have written your Catalyst application, but the
Views are catering for the users and as an admin you'd like a more direct,
secondary web interface to the database.

 package ListFrameworkUser;
 use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);
 
 __PACKAGE__->setup;
 1;

Adding C<CatalystX::ListFramework::Builder> (LFB) as a plugin to your Catalyst
application, as above, causes it to scan your existing Models. If any of them
are built using L<Catalyst::Model::DBIC::Schema>, they are automatically
loaded. You still need to provide a small amount of configuration:

 extjs2   /static/javascript/extjs-2
 <Controller::LFB::Root>
     <action>
         <base>
             PathPart   admin
         </base>
     </action>
 </Controller::LFB::Root>

First the application needs to know where your copy of ExtJS is, on the web
server.  Use the C<extjs2> option as shown above to specify the URL path to
the libraries. This will be used in the templates in some way like this:

 <script type="text/javascript" src="[% c.config.extjs2 %]/ext-all.js" />

In the above example, the path C<...E<sol>adminE<sol>> will contain the LFB
application, and all generated links in LFB will also make use of that path.
Remember this is added to the C<base> of your Cataylst application which,
depending on your web server configuration, might also have a leading path.

This mode of operation works even if you have more than one database. You will
be offered a Home screen to select the database, and then another menu to
select the table within that.

=head2 Scenario 2: Frontend for an existing C<DBIx::Class::Schema> based class

In this mode, C<CatalystX::ListFramework::Builder> (LFB) is running
standalone, in a sense as the Catalyst application itself. Your main
application file looks the same as in Scenario 1, though:

 package ListFrameworkUser;
 use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);
 
 __PACKAGE__->setup;
 1;

For the configuration, you need to tell LFB which package contains the
C<DBIx::Class> schema, and also provide database connection parameters.

 extjs2   /static/javascript/extjs-2
 <Model::LFB::DBIC>
     schema_class   My::Database::Schema
     connect_info   dbi:Pg:dbname=mydbname;host=mydbhost.example.com;
     connect_info   username
     connect_info   password
     <connect_info>
         AutoCommit   1
     </connect_info>
 </Model::LFB::DBIC>

First the application needs to know where your copy of ExtJS is, on the web
server.  Use the C<extjs2> option as shown above to specify the URL path to
the libraries. This will be used in the templates in some way like this:

 <script type="text/javascript" src="[% c.config.extjs2 %]/ext-all.js" />

The C<Model::LFB::DBIC> section must look (and be named) exactly like that
above, except you should of course change the C<schema_class> value and the
values within C<connect_info>.

=head3 C<DBIx::Class> setup

You will of course need the C<DBIx::Class> schema to be created and installed
on your system. The recommended way to do this quickly is to use the excellent
L<DBIx::Class::Schema::Loader> module which connects to your database and
writes C<DBIx::Class> Perl modules for it.

Pick a suitable namespace for your schema, which is not related to this
application. For example C<DBIC::Database::Foo::Schema> for the C<Foo>
database (in the configuration example above we used C<My::Database::Schema>).
Then use the following command-line incantation:

 perl -MDBIx::Class::Schema::Loader=make_schema_at,dump_to_dir:. -e \
     'make_schema_at("DBIC::Database::Foo::Schema", { debug => 1 }, \
     ["dbi:Pg:dbname=foodb;host=mydbhost.example.com","user","pass" ])'

This will create a directory (such as C<DBIC>) which you need to move into
your Perl Include path (one of the paths shown at the end of C<perl -V>).

=head2 Scenario 3: Lazy loading a C<DBIx::Class> schema

If you're in such a hurry that you can't create the C<DBIx::Class> schema, as
shown in the previous section, then C<CatalystX::ListFramework::Builder> (LFB)
is able to do this on the fly, but it will slow the application down a little.

The application file and configuration are very similar to those in Scenario
2, above, except that you omit the C<schema_class> configuration option
because you want LFB to generate that on the fly (rather than reading an
existing one from disk).

 package ListFrameworkUser;
 use Catalyst qw(ConfigLoader +CatalystX::ListFramework::Builder);
 
 __PACKAGE__->setup;
 1;

 extjs2   /static/javascript/extjs-2
 <Model::LFB::DBIC>
     connect_info   dbi:Pg:dbname=mydbname;host=mydbhost.example.com;
     connect_info   username
     connect_info   password
     <connect_info>
         AutoCommit   1
     </connect_info>
 </Model::LFB::DBIC>

When LFB loads it will connect to the database and use the
L<DBIx::Class::Schema::Loader> module to reverse engineer its schema. To work
properly you'll need the very latest version of that module (0.05 or greater).

The other drawback to this scenario (other than the slower operation) is that
you have no ability to customize how foreign, related records are shown.  A
related record will simply be represented as something approximating the name
of the foreign table, the names of the primary keys, and associated values
(e.g. C<id(5)>).

=head1 TIPS AND TRICKS

=head2 Representing related records

When the web interface wants to display a column which references another
table, you can make things look much better by adding a custom render method
to your C<DBIx::Class> Result Classes (i.e. the class files for each table).

First, the application will look for a method called C<display_name> and use
that. Here is an example which could be added to your Result Class files below
the line which reads C<DO NOT MODIFY THIS OR ANYTHING ABOVE>, and in this case
returns the data from the C<title> column:

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

=head2 Columns with auto-increment data types

For those columns where your database uses an auto-incremented value, add the
C<< is_auto_increment => 1, >> option to the relevant hash in add_columns().
This will let the application know you don't need to supply a value for new or
updated records. The interface will look much better as a result.

=head2 Database IO filters

Buried within one of the modules in this application are some filters which
are applied to data of certain types as it enters or leaves the database. If
you find a particular data type is not being rendered correctly, please drop
the author a line at the email address below, explaining what you'd like to
see instead.

=head2 Relocating LFB to another URL path

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

=head1 EXAMPLES

The code examples give above in this manual are also supplied in the form of a
sample application. You'll find the application itself in the C<examples/app/>
directory of this distribution, and the SQLite3 data source in the
C<examples/sql/> directory.

=head1 INSTANT DEMO APPLICATION

If you want to run an instant demo of this module, with minimal configuration,
then a simple application for that is shipped with this distribution. For this
to work, you must have the very latest version of
L<DBIx::Class::Schema::Loader> installed on your system (> 0.04005).

First go to the C<examples/demo/> directory of this distribution and edit
C<demo.conf> so that it contains the correct C<dsn>, username, and password
for your database. Next, download a copy of the ExtJS 2.x Javascript library,
and make a note of where you put it. Then create the following directory, and
symbolic link:

 demo> mkdir -p root/static
 demo> ln -s /path/to/your/extjs-2 root/static/extjs-2

Now start the demo application like so:

 demo> perl ./server.pl

Although the instruction at the end of the output says to visit (something
like) C<http://localhost:3000>, you I<must> instead visit
C<http://localhost:3000/lfb/> (i.e. add C</lfb/> to the end).

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

Catalyst::Action::RenderView

=item *

MRO::Compat

=back

=head1 SEE ALSO

L<CatalystX::CRUD> and L<CatalystX::CRUD:YUI> are two distributions which
allow you to create something similar but with full customization, and the
ability to add more features. So, you trade effort for flexibility and power.

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

This distribution ships with the Ext.ux.form.DateTime Extension Class for Ext
2.x Library, Copyright (c) 2008, Ing. Jozef Sakalos, and released under the
LGPL 3.0 license (library version 289, 2008-06-12 21:08:08).

The rest is Copyright (c) Oliver Gorwits 2008.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

