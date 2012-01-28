#!/usr/bin/perl

=head1 NAME

evalbot.pl - a pluggable p5 evalbot

=head1 SYNOPSIS

perl -Ilib evalbot.pl <configfile>

=head1 DESCRIPTION

evalbot.pl is a perl5 based evalbot, intended for the different Perl 6
implementations.

Take a look at the example config file that is hopefully is the same 
directory.

=head1 AUTHOR

Written by Moritz Lenz, many good contributions came from the #perl6 folks, 
notably diakopter, Mitchell Charity (putter), Adrian Kreher (Auzon), rhr, 
Stefan O'Rear (sorear), and all those that I forgot.

Copyright (C) 2007-2011 by Moritz Lenz and the pugs authors.

This file may be distributed under the same terms as perl or pugs itself.

=cut

use warnings;
use strict;

use Bot::BasicBot;
use Config::File;
use Carp qw(confess);
use Data::Dumper;
use FindBin;
use lib 'lib';
use EvalbotExecuter;
use utf8;

# $ENV{LD_LIBRARY_PATH} = '/usr/local/lib/';

package Evalbot;
{
    use base 'Bot::BasicBot';
    use File::Temp qw(tempfile);
    use Carp qw(confess);
    use Scalar::Util qw(reftype);
    my $prefix  = '';
    my $postfix = qr/:\s/;

    my $home = glob '~';

    our %impls = (
            'partcl' => {
                chdir       => "$home/partcl-nqp",
                cmd_line    => './partcl %program',
                filter      => \&filter_pct,
                revision    => sub { get_revision_from_file('/home/p6eval/partcl-nqp/.revision', 6)},
            },
            perlesque => {
                chdir       => "$home/sprixel/sprixel/sprixel/bin/Release",
                cmd_line    => '/home/p6eval/sprixel/clr/bin/mono --gc=sgen sprixel.exe -s %program',
            },
            mildew  => {
                chdir       => $home,
                cmd_line    => '/home/mildew/perl5/perlbrew/bin/perl /home/mildew/perl5/perlbrew/perls/current/bin/mildew %program',
            },
            niecza => {
                chdir       => "$home/niecza",
                cmd_line    => 'PATH=/usr/local/mono-2.10.1/bin:/usr/local/bin:/usr/bin:/bin LD_LIBRARY_PATH=/usr/local/mono-2.10.1/lib mono ./run/Niecza.exe --safe %program',
                revision    => sub { get_revision_from_file('~/niecza/VERSION')},
            },
            nqpnet => {
                chdir       => "$home/6model/dotnet/compiler",
                cmd_line    => './try2.sh %program',
                #revision    => sub { get_revision_from_file('~/6model/VERSION'
            },
            nqplua => {
                chdir       => "$home/nqplua/6model/lua/compiler",
                cmd_line    => './try.sh %program',
                #revision    => sub { get_revision_from_file('~/nqplua/VERSION'
            },
            b => {
                chdir       => "$home/rakudo/",
                cmd_line    => 'PERL6LIB=lib ../p/bin/perl6 %program',
                revision    => sub { get_revision_from_file('~/p/rakudo-revision')},
                nolock      => 1,
                filter      => \&filter_pct,
# Rakudo loops infinitely when first using Safe.pm, and then declaring
# another class. So don't do that, rather inline the contents of Safe.pm.
                program_prefix => q<
module Safe { our sub forbidden(*@a, *%h) { die "Operation not permitted in safe mode" };
    Q:PIR {
        $P0 = get_hll_namespace
        $P1 = get_hll_global ['Safe'], '&forbidden'
        $P0['!qx']  = $P1
        null $P1
        set_hll_global ['IO'], 'Socket', $P1
    }; };
Q:PIR {
    .local pmc s
    s = get_hll_global ['Safe'], '&forbidden'
    $P0 = getinterp
    $P0 = $P0['outer';'lexpad';1]
    $P0['&run'] = s
    $P0['&open'] = s
    $P0['&slurp'] = s
    $P0['&unlink'] = s
    $P0['&dir'] = s
};
# EVALBOT ARTIFACT
>,
            },
            rakudo => {
                chdir       => "$home",
                cmd_line    => './nom-inst/bin/perl6 --setting=SAFE %program',
                filter      => \&filter_pct,
                nolock      => 1,
                revision    => sub { get_revision_from_file('~/nom-inst/rakudo-revision')},
            },
            nom => {
                chdir       => "$home",
                cmd_line    => './nom-inst/bin/perl6 --setting=SAFE %program',
                filter      => \&filter_pct,
                nolock      => 1,
                revision    => sub { get_revision_from_file('~/nom-inst/rakudo-revision')},
            },
            star => {
                chdir       => "$home/rakudo-star-2012.01/",
                cmd_line    => './install/bin/perl6 --setting=SAFE %program',
                revision    => sub { '2012.01' },
                filter      => \&filter_pct,
            },
            alpha => {
                chdir       => "$home/rakudo-alpha/",
                cmd_line    => 'PERL6LIB=lib ../rakudo-alpha/perl6 %program',
                revision    => sub { get_revision_from_file('~/rakudo-alpha/revision')},
                filter      => \&filter_pct,
                program_prefix => 'my $ss_SS_S_S__S_S_s = -> *@a, *%h { die "operation not permitted in safe mode" };
    Q:PIR {
$P0 = get_hll_namespace
$P1 = find_lex \'$ss_SS_S_S__S_S_s\'
$P0[\'run\']  = $P1
$P0[\'open\'] = $P1
$P0[\'!qx\']  = $P1
null $P1
set_hll_global [\'IO\'], \'Socket\', $P0
    };',
            },
            nqp   => {
                chdir       => "$home/nqp",
                cmd_line    => './nqp %program',
                filter      => \&filter_pct,
            },
            nqprx => {
                chdir       => "$home/nqp-rx",
                cmd_line    => './nqp %program',
                filter      => \&filter_pct,
            },
            pugs => {
                cmd_line    => 'PUGS_SAFEMODE=true ~/ghc-7.2.1/bin/pugs %program',
                revision    => sub { get_revision_from_file("$home/ghc-7.2.1/pugs_version")},
            },
            std  => {
                chdir       => "$home/std/snap",
                cmd_line    => 'perl -I. tryfile %program',
                revision    => sub { get_revision_from_file("$home/std/snap/revision")},
                nolock      => 1,
            },
            yapsi   => {
                chdir       => "$home/yapsi",
                cmd_line    => 'PERL6LIB=lib /home/p6eval/p/bin/perl6 bin/yapsi %program',
            },
            highlight  => {
                chdir       => "$home/std/snap/std_hilite",
                cmd_line    => $^X . ' STD_syntax_highlight %program',
                revision    => sub { get_revision_from_file("$home/std/snap/revision")},
            },
    );

    my $evalbot_version = get_revision();

    my $regex = $prefix . '(' . join('|',  keys %impls) . ")$postfix";

    sub help {
        return "Usage: <$regex \$perl6_program>";
    }
#    warn "Regex: ", $regex, "\n";

    sub said {
        my $self = shift;
        my $info = shift;
        my $message = $info->{body};
        my $address = $info->{address} // '';
        return if $info->{who} =~ m/^dalek.?$/;
        $message =~ s/␤/\n/g;

        if ($message =~ m/^p6eval:/) {
            return "Usage: ", join(',', sort keys %impls), ': $code';
        } elsif ($message =~ m/\A$regex\s*(.*)\z/s){
            my ($eval_name, $str) = ($1, $2);
            my $e = $impls{$eval_name};
            return "Please use /msg $self->{nick} $str" 
                if($eval_name eq 'highlight');
            warn "$info->{channel} <$info->{who}> $eval_name: $str\n";
            my $result = EvalbotExecuter::run($str, $e, $eval_name);
            my $revision = '';
            if (reftype($e) eq 'HASH' && $e->{revision}){
                $revision = ' ' . $e->{revision}->();
            }
            return sprintf "%s%s: %s", $eval_name, $revision, $result;
        } elsif ( $message =~ m/\Aperl6:\s+(.+)\z/s ){
            my $str = $1;
            return "Program empty" unless length $str;
            warn "$info->{channel} <$info->{who}> Perl6: $str\n";
            my %results;
            for my $eval_name (qw(pugs rakudo niecza)) {
                my $e = $impls{$eval_name};
                my $tmp_res = EvalbotExecuter::run($str, $e, $eval_name);
                my $revision = '';
                if (reftype($e) eq 'HASH' && $e->{revision}){
                    $revision = ' ' . $e->{revision}->();
                }
                push @{$results{$tmp_res}}, "$eval_name$revision";
            }
            my $result = '';
            while (my ($text, $names) = each %results){
                $result .= join(', ', @$names);
                $result .= sprintf(": %s\n", $text);
            }
            return $result;

        } elsif ( $message =~ m/\Aevalbot\s*control\s+(\w+)/) {
            my $command = $1;
            if ($command eq 'restart'){
                warn "Restarting $0 (by user request)\n";
                # we do hope that evalbot is started in an endless loop ;-)
                exit;
            } elsif ($command eq 'version'){
                return "This is evalbot revision $evalbot_version";
            }
        } elsif ($message =~ m/\Aevalbot\s*rebuild\s+(\w+)/) {
            my $name = "$1";
            # XXX We want better integration so that this can go to the right place
            if (EvalbotExecuter::try_lock($name)) {
                system "(./build.pl $name; echo 'freenode #perl6 Rebuild of $name complete.' >> /home/p6eval/dalek-queue) &";
                return "OK (started asynchronously)";
            } else {
                return "NOT OK (maybe a rebuild is already in progress?)";
            }
        }
        return;
    }

    sub get_revision {
        qx/git log --pretty=%h -1/;
    }

    sub get_revision_from_file {
        my $file = shift;
        my $len  = shift;
        my $res = `cat $file`;
        chomp $res;
        if (defined($len)) {
            return substr($res, 0, $len);
        }
        return $res;
    }

    sub filter_pct {
        my $str = shift;
        $str =~ s/called from Sub.*//ms;
        return $str;
    }

    sub filter_kp6 {
        my $str = shift;
        $str =~ s/KindaPerl6::Runtime.*//ms;
        return $str;
    }

    sub filter_std {
        my $str = shift;
        if($str =~ /PARSE FAILED/) {
            my @lines = grep {!/-+>/ && !/PARSE FAILED/} split /\n/, $str;
            return join '', @lines;
        } elsif($str =~ /Out of memory!/) {
            return 'Out of memory!';
        } else {
            return "parse OK";
        }
    }
}

package main;

my $config_file = shift @ARGV 
    or confess("Usage: $0 <config_file>\n   or: $0 -run <impl> <code>");

if ($config_file eq '-run') {
    my ($eval_name, $str) = @ARGV;
    my $e = $Evalbot::impls{$eval_name};
    die("No such implementation.\n") unless $e;
    my $result = EvalbotExecuter::run($str, $e, $eval_name);
    my $revision = '';
    if (Scalar::Util::reftype($e) eq 'HASH' && $e->{revision}){
	$revision = ' ' . $e->{revision}->();
    }
    binmode STDOUT, ':utf8';
    printf "%s%s: %s\n", $eval_name, $revision, $result;
    exit 0;
}

my %conf = %{ Config::File::read_config_file($config_file) };

#warn Dumper(\%conf);

my $bot = Evalbot->new(
        server => $conf{server},
        port   => $conf{port} || 6667,
        channels  => [ map { "#$_" } split m/\s+/, $conf{channels} ],
        nick      => $conf{nick},
        alt_nicks => [ split m/\s+/, $conf{alt_nicks} ],
        username  => "p6eval",
        name      => "combined, experimental evalbot",
        charset   => "utf-8",
        );
$bot->run();

# vim: ts=4 sw=4 expandtab
