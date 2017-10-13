#!/usr/bin/env perl
use strict;
use warnings;
use File::Path qw(rmtree);
use 5.010;
use autodie;
use Data::Dumper;

my $force = shift(@ARGV) // 0;
say scalar localtime();
chdir glob '~';

my $home = glob('~') . '/';
my @dirs = qw(rakudo-j-inst-1 rakudo-j-inst-2);
my %swap = (@dirs, reverse(@dirs));

my $link = 'rakudo-j-inst';

# starting up?
if (not -d $dirs[0] or not -d $dirs[1]) {
    for my $d (@dirs) {
        mkdir $d, 0777;
        (my $s = $d) =~ s/-inst//;
        system 'git', 'clone', 'https://github.com/rakudo/rakudo.git', $s;
    }
    symlink $dirs[1], $link;
}

my $now = readlink $link;
my $other = $swap{$now} // $dirs[0];

say "Other: '$other'";
my $source_dir = $other;
$source_dir =~ s/-inst//;
chdir $source_dir;
system('git', 'pull');

my $revision_file = "$home$other/revision";
eval {
    open my $fh, '<', $revision_file or break;
    my $r = <$fh>;
    close $fh;

    chomp $r;
    my $needs_rebuild = `git rev-parse HEAD | grep ^\Q$r\E|wc -l`;
    chomp $needs_rebuild;
    if (!$force && $needs_rebuild) {
        say "Don't need to rebuild, we are on the newest revision anyway";
        exit;
    }
};
warn $@ if $@;

rmtree glob "$home/$other/*";
system('git', 'clean', '-xdf');
system($^X, 'Configure.pl', "--prefix=$home/$other",
            '--backends=jvm', '--gen-nqp') and die $?;
system('make', 'j-install')                           and die $?;

system("git rev-parse HEAD | cut -b 1-9 > $revision_file") and warn $?;

chdir $home;
unlink $link;
symlink $other, $link;
