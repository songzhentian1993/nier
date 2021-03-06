use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Nier',
    VERSION_FROM => 'lib/Nier.pm',
    ABSTRACT_FROM => 'lib/Nier.pm',
    LICENSE => 'gpl_2',
    AUTHOR => [
        'songzhentian',
    ],
    EXE_FILES => ['bin/nier'],
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.52',
    },
    PREREQ_PM => {
        'DBI' => '0',
        'DBD::SQLite' => '0',
        'File::Basename' => '0',
        'File::Find' => '0',
        'File::Spec::Functions' => '0',
        'File::Temp' => '0',
        'Getopt::Std' => '0',
        'IPC::Open3' => '0',
        'Spreadsheet::WriteExcel' => '0',
        'IO::CaptureOutput' => '0',
                  
    },
    TEST_REQUIRES => {
        'File::Temp' => '0',
        'Test::More' => '0.98',
        'Test::Pod' => '1.00',
        'Test::Strict' => '0',
    },
    META_MERGE => {
        resources => {
            homepage => 'http://nier.turingmachine.org/',
            repository => 'https://github.com/songzhentian1993/nier',
            license => 'http://www.gnu.org/licenses/gpl-2.0.html',
       },
    },
);
