#!/usr/bin/env perl

my $loc = $0;
$loc =~ s/\.pl$//;
system "$loc-moar.pl", @ARGV;
system "$loc-jvm.pl", @ARGV;
