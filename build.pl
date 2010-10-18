#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;

use autodie;
use List::Util qw(first);
use FindBin;

my $what = shift(@ARGV) or die "Usage: $0 <project>\n";

my $script_dir = "$FindBin::Bin/build-scripts/";
my $script = first { -e $_ } "$script_dir/$what.pl", "$script_dir/$what.sh";

die "Found no rebuild script for $what\n" unless $script_dir;

exec "$script 2>&1 >~/log/$what.log";
