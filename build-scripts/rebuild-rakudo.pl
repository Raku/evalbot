#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(rmtree);
use 5.010;
use autodie;
use Data::Dumper;

chdir glob '~';

my $home = glob('~') . '/';
my @dirs = qw(rakudo-inst-1 rakudo-inst-2);
my %swap = (@dirs, reverse(@dirs));

my $link = 'rakudo-inst';

my $now = readlink $link;
my $other = $swap{$now};

say "Other: '$other'";
my $source_dir = $other;
$source_dir =~ s/-inst-//;
chdir $source_dir;
system('git', 'pull');

my $revision_file = "$home$other/revision";
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

system('git', 'clean', '-xdf');
system($^X, 'Configure.pl', "--prefix=$home/$other",
            '--backends=parrot,jvm', '--gen-nqp', '--gen-parrot') and die $?;
system('make', 'install')                           and die $?;

system("git rev-parse HEAD | cut -b 1-6 > $revision_file") and warn $?;

chdir $home;
unlink $link;
symlink $other, $link;
