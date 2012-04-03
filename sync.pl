use 5.010;
use strict;
use warnings;
my $sync = shift;

my %dirs = (
    rakudo  => [qw/p1 p2 p/, ''],
    nom     => [qw/nom-inst1 nom-inst2 nom-inst/, ''],
    niecza  => [qw/niecza/, ''],
    pugs    => [qw!Pugs.hs/Pugs/ Pugs.hs/Pugs/!],
    std     => [qw!std/snap/ std/snap/!],
);

if ($dirs{$sync}) {
    my @to_sync = @{$dirs{sync}};
    my $dest    = pop @to_sync;
    system('rsync', '-az', '--delete', @to_sync, "feather3:$dest");
    if ($? == -1) {
        say "failed to execute rsync: $!";
        exit 2;
    }
}
else {
    say "No synchronization target for '$sync'";
    exit 1;
}
