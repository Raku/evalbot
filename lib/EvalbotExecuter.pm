package EvalbotExecuter;

=head1 NAME

EvalbotExecuter - Execution of external programs for evalbot

=head1 SYNOPSIS

    use EvalbotExecuter;

    sub my_evalbot_executer {
        my ($program, $fh, $filename) = @_;

        # execute $program, and write the result to
        # $fh, which is a filehandle opened for reading.
        # $filename is the name of that file.

        # we make a very stupid 'eval': remove all
        # vowels, and write it:

        $program =~ s/[aeiou]//g;
        print $fh $program;
        close $fh;

        # the return value doesn't really matter
        return;
    }

    # somewhere else in the program, run it:
    EvalbotExecuter::run('say "foo"', \&my_evalbot_executer);

=head1 DESCRIPTION

EvalbotExecuter is basically a wrapper around a function that executes an
external program.

Currently it does the following:

=over

=item *

Set up a temporary file that should capture the output

=item *

Fork a child process

=item *

Set resource limits in the child process

=item *

call an external function that starts an external process

=item *

collects the contents of the temporary file, postprocess it, and unlink
the temp file.

=back

=cut


use strict;
use warnings;
use utf8;
use Config;
use BSD::Resource;
use Carp qw(confess);
use File::Temp qw(tempfile);
use Scalar::Util qw(reftype);
use Encode qw(encode);
use charnames qw(:full);
use POSIX ();
use Encode qw/decode_utf8/;

my $max_output_len = 290;

sub run {
    my ($program, $executer, $ename) = @_;
    if ($program =~ /^https:\/\/gist\.github\.com\/[^\/]+?\/\p{HexDigit}+$/) {
      my $page = `curl -s $program`;
      $page =~ /<a title="View Raw" href="([^"]+)"/;
      if ($1) { $program = decode_utf8 `curl -s https://gist.github.com$1` } else { return 'gist not found' };
    } elsif ($program =~ /^https:\/\/github\.com\/([^\/]+\/[^\/]+)\/blob\/([^\/]+\/[^\/].*)$/) {
      my ($project, $file) = ($1, $2);
      my $page = `curl -s $program`;
      if ($page =~ /href="\/$project\/raw\/$file"/) {
      	$program = decode_utf8 `curl -s https://raw.github.com/$project/$file`
      } else {
      	return 'file not found'
      };
    }
    return _fork_and_eval($program, $executer, $ename);
}

sub _fork_and_eval {
    my ($program, $executer, $ename) = @_;

# the forked process should write its output to this tempfile:
    my ($fh, $filename) = tempfile();
    chmod 0644, $filename;

    my $fork_val = fork;
    my $timed_out = 0;
    if (!defined $fork_val){
        confess "Can't fork(): $!";
    } elsif ($fork_val == 0) {
        POSIX::setpgid($$,$$);
        _set_resource_limits();
        _auto_execute($executer, $program, $fh, $filename, $ename);
    } else {
# server
	alarm 12;
        local $SIG{ALRM} = sub {
            $timed_out = 1;
            kill 15, -$fork_val;
            alarm 0;
        };

        wait;
        alarm 0;
    }

    # gather result
    close $fh;
    open ($fh, '<:encoding(UTF-8)', $filename) or confess "Can't open temp file <$filename>: $!";
    my $result = do { local $/; <$fh> };
    unlink $filename or warn "couldn't delete '$filename': $!";
    if ($timed_out) {
	$result = "(timeout)" . $result;
    } elsif ($? & 127) {
        $result = "(signal " . (split ' ', $Config{sig_name})[$?] . ")" . $result;
    }
    if (reftype($executer) eq 'HASH' && $executer->{filter}){
        $result = $executer->{filter}->($result);
    }
    $result =~ s/\Q$filename\E/<program>/g;
    return $result;
}

sub try_lock {
    my $name = shift;
    my $lockfile = "/home/p6eval/evalbot/build-scripts/lock.$name";
    open my $lock, '>', $lockfile or return;
    flock($lock, 6) && $lock;
}

sub _auto_execute {
    my ($executer, $program, $fh, $out_filename, $lock_name) = @_;
    local $^F = 1000;
    open STDOUT, ">&", $fh;
    open STDERR, ">&", $fh;
    # TODO: avoid hardcoded path
    open STDIN, "<", glob '~/evalbot/stdin';
    my $lock;
    if (!$executer->{nolock} && !($lock = try_lock($lock_name)) ) {
        print "Rebuild in progress\n";
        exit 1;
    }
    if ($executer->{chdir}){
        chdir $executer->{chdir}
            or confess "Can't chdir to '$executer->{chdir}': $!";
    }
    if (exists $executer->{program_prefix}) {
        $program = $executer->{program_prefix} . $program;
    }
    if (exists $executer->{program_suffix}) {
        $program .= $executer->{program_suffix};
    }
    if (exists $executer->{program_munger}) {
        $program = $executer->{program_munger}->($program);
    }
    my $cmd = $executer->{cmd_line} or confess "No command line given\n";
    my ($prog_fh, $program_file_name) = tempfile();
    binmode $prog_fh, ':encoding(UTF-8)';
    print $prog_fh $program;
    close $prog_fh;
    chmod 0644, $program_file_name;

    $cmd =~ s/\%program\b/$program_file_name/g;
    close $fh;
    exec($cmd);
    die "exec ($cmd) failed: $!\n";
}

sub _set_resource_limits {
# stolen from evalhelper-p5.pl
    setrlimit RLIMIT_CPU,  15, 20                    or confess "Couldn't setrlimit: $!\n";
#    setrlimit RLIMIT_VMEM,  500 * 2**20, 200 * 2**20 or confess "Couldn't setrlimit: $!\n";
# STD.pm has a lexing subdir, varying in size, so allow 15MB
    my $size_limit = 15 * 1024**2;
    setrlimit RLIMIT_FSIZE, $size_limit, $size_limit or confess "Couldn't setrlimit: $!\n";
}

1;
# vim: sw=4 ts=4 expandtab syn=perl
