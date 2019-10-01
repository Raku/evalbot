#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;

use autodie;
use List::Util qw(first);
use FindBin;
use Fcntl qw(:DEFAULT :flock);

my $what = shift(@ARGV) or die "Usage: $0 <project>\n";

my $script_dir = "$FindBin::Bin/build-scripts/";
my $script = first { -e $_ } "$script_dir/rebuild-$what.pl", "$script_dir/rebuild-$what.sh";

die "Found no rebuild script for $what\n" unless $script;
open my $lock_file, '>', "$script.lock"
    or die "Cannot open lock $script.lock: $!";
flock( $lock_file, LOCK_EX | LOCK_NB )
    or die "Cannot lock file $script.lock: $!";

system "flock -w 60 $script_dir/lock.$what $script @ARGV >~/log/$what.log 2>&1";
flock ( $lock_file, LOCK_UN );
close $lock_file;
unlink "$script.lock";
#system $^X, "$FindBin::Bin/sync.pl",  $what;
