use 5.008004;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME              => 'CatalystX::ListFramework::Builder',
    VERSION_FROM      => 'lib/CatalystX/ListFramework/Builder.pm', # finds $VERSION
    PREREQ_PM         => {
        Catalyst::Runtime => 5.70,
        Catalyst::Model::DBIC::Schema => 0,
        Catalyst::View::JSON => 0,
        Catalyst::View::TT => 0,
        Class::C3 => 0,
        Class::Data::Inheritable => 0,
        List::MoreUtils => 0,
    },

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/CatalystX/ListFramework/Builder.pm',
       AUTHOR         => 'Oliver Gorwits <oliver.gorwits@oucs.ox.ac.uk>') : ()),

    dist        => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean       => { FILES => 'Catalyst-ListFramework-Builder-*' },
    realclean   => { FILES => 'Makefile.old' },
);

