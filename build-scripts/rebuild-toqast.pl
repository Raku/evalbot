#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(rmtree);
use 5.010;
use autodie;
use Data::Dumper;

my $home = glob('~');
my $qhome = "$home/toqast";


chdir "$qhome/parrot";
system('git', 'pull');
chdir "$qhome/nqp";
system('git', 'checkout', 'toqast');
system('git', 'pull');
chdir $qhome;
system('git', 'pull');

my $revision_file = "$qhome/rakudo-revision";
eval {
    open my $fh, '<', $revision_file or break;
    my $r = <$fh>;
    close $fh;

    chomp $r;
    my $needs_rebuild = `git rev-parse HEAD | grep ^$r|wc -l`;
    chomp $needs_rebuild;
    if ($needs_rebuild) {
        say "Don't need to rebuild, we are on the newest revision anyway";
        exit;
    }
};

chdir "$qhome/parrot";
system($^X, 'Configure.pl', "--prefix=$qhome/install", '--optimize');
system('make', 'install')
                                and die $?;
chdir "$qhome/nqp";
system($^X, 'Configure.pl', "--with-parrot=$qhome/install/bin/parrot");
system('make', 'install')       and die $?;
chdir $qhome;
system($^X, 'Configure.pl');
system('make', 'install')       and die $?;
system("git rev-parse HEAD | cut -b 1,2,3,4,5,6 > $revision_file") and warn $?;

