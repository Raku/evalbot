#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;

use autodie;
use List::Util qw(first);
use FindBin;

my $what = shift(@ARGV) or die "Usage: $0 <project>\n";

my $script_dir = "$FindBin::Bin/build-scripts/";
my $script = first { -e $_ } "$script_dir/rebuild-$what.pl", "$script_dir/rebuild-$what.sh";

die "Found no rebuild script for $what\n" unless $script;

system "flock -w 60 $script_dir/lock.$what $script @ARGV >~/log/$what.log 2>&1";
unlink "$script_dir/lock.$what";
#system $^X, "$FindBin::Bin/sync.pl",  $what;
