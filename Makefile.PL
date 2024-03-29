use strict;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'             => 'Char',
    'VERSION_FROM'     => 'Char.pm', # finds $VERSION
    ($] >= 5.005 ?                   # Add these new keywords supported since 5.005
      ('PREREQ_PM'     => {},        # e.g., Module::Name => 1.1
       'ABSTRACT_FROM' => 'Char.pm', # retrieve abstract from module
       'AUTHOR'        => 'ina <ina@cpan.org>',
      )
      :
      ()
    ),
);
__END__
