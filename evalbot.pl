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
use IRC::FromANSI::Tiny;
use utf8;

# $ENV{LD_LIBRARY_PATH} = '/usr/local/lib/';

package Evalbot;
{
    use base 'Bot::BasicBot';
    use File::Temp qw(tempfile);
    use Carp qw(confess);
    use Scalar::Util qw(reftype);
    use Encode qw(encode_utf8);
    use charnames qw(:full);
    my $prefix  = '';
    my $postfix = qr/:\s/;

    my $home = glob '~';
    my $max_output_len = 290;

    my %aliases = (
        nom     => ['rakudo-moar'],
        rakudo  => ['rakudo-moar'],
        r       => ['rakudo-moar', 'rakudo-jvm'],
        'r-m'   => 'rakudo-moar',
        'rm'    => 'rakudo-moar',
        m       => 'rakudo-moar',
        'P'     => 'pugs',
        n   => 'niecza',
        p6  => [qw/rakudo-moar/],
        perl6  => [qw/rakudo-moar rakudo-jvm/],
        rn  => [qw/rakudo-moar niecza/ ],
        nr  => [qw/rakudo-moar niecza/ ],
        nqp => [qw/nqp-moarvm nqp-jvm nqp-parrot/],
        'nqp-p'   => 'nqp-parrot',
        'nqp-j'   => 'nqp-jvm',
        'nqp-m'   => 'nqp-moarvm',
        'nqp-mvm' => 'nqp-moarvm',
        'nqp-q'   => 'nqp-js',
        'r-jvm'   => 'rakudo-jvm',
        'r-j'     => 'rakudo-jvm',
        'rj'      => 'rakudo-jvm',
        'j'       => 'rakudo-jvm',
        'p56'     => 'p5-to-p6',
        star      => ['star-m', 'star-j'],
        sj        => 'star-j',
        sm        => 'star-m',
        sp        => 'star-p',
    );
    $aliases{$_} = [qw/rakudo-jvm niecza pugs/] for qw/rnP rPn nrP nPr Prn Pnr/;

    our %impls = (
            niecza => {
                chdir       => "$home/niecza",
                cmd_line    => 'PATH=/usr/local/mono-2.10.1/bin:/usr/local/bin:/usr/bin:/bin LD_LIBRARY_PATH=/usr/local/mono-2.10.1/lib mono ./run/Niecza.exe --safe --obj-dir=obj %program',
                revision    => sub { get_revision_from_file('~/niecza/VERSION')},
            },
            'rakudo-moar' => {
                chdir       => "$home",
                cmd_line    => './rakudo-inst/bin/perl6-m --setting=RESTRICTED %program',
                nolock      => 1,
                revision    => sub { get_revision_from_file('~/rakudo-inst/revision')},
            },
            'prof-m' => {
                chdir       => "$home",
                cmd_line    => './rakudo-inst/bin/perl6-m --profile --profile-filename=/tmp/mprof.html --setting=RESTRICTED %program',
                nolock      => 1,
                revision    => sub { get_revision_from_file('~/rakudo-inst/revision')},
                post        => sub {
                    my ($output) = @_;
                    my $destfile = sprintf "%x", time - 1420066800; # seconds since 2015-01-01
                    print "\nnow running scp...\n";
                    system("scp", '-q', '/tmp/mprof.html', "p.p6c.org\@www.p6c.org:public/$destfile.html");
                    return ('Prof' => "http://p.p6c.org/$destfile");
                },
            },
            'star-m' => {
                chdir       => "$home/star/",
                cmd_line    => './bin/perl6-m --setting=RESTRICTED %program',
                revision    => sub { get_revision_from_file("$home/star/version") },
            },
            'star-p' => {
                chdir       => "$home/star/",
                cmd_line    => './bin/perl6-p --setting=RESTRICTED %program',
                revision    => sub { get_revision_from_file("$home/star/version") },
            },
            'star-j' => {
                chdir       => "$home/star/",
                cmd_line    => './bin/perl6-j --setting=RESTRICTED %program',
                revision    => sub { get_revision_from_file("$home/star/version") },
            },
            'nqp-parrot' => {
                chdir       => "$home",
                cmd_line    => './rakudo-inst/bin/nqp-p %program',
                filter      => \&filter_pct,
            },
            'nqp-jvm'    => {
                chdir       => $home,
                cmd_line    => './rakudo-inst/bin/nqp-j %program',
            },
            'nqp-moarvm' => {
                chdir       => $home,
                cmd_line    => './rakudo-inst/bin/nqp-m %program',
            },
            'nqp-js'     => {
                chdir       => "$home/nqp-js",
                cmd_line    => './nqp-js %program',
            },
            'rakudo-jvm' => {
                chdir       => $home,
                cmd_line    => "$^X $home/rakudo-inst/bin/eval-client.pl $home/p6eval-token run_limited 15  %program",
                revision    => sub { get_revision_from_file("$home/rakudo-inst/revision")},
            },
            pugs => {
                cmd_line    => "PUGS_SAFEMODE=true LC_ALL=en_US.ISO-8859-1 $home/.cabal/bin/pugs %program",
            },
            std  => {
                chdir       => "$home/std/snap",
                cmd_line    => 'perl -I. tryfile %program',
                revision    => sub { get_revision_from_file("$home/std/snap/revision")},
                nolock      => 1,
            },
            'p5-to-p6' => {
                chdir       => "$home/Perlito",
                cmd_line    => "perl perlito5.pl --noboilerplate -I./src5/lib -Cperl6 %program",
                revision    => sub {
                    my $r = qx/cd $home && Perlito && git describe/;
                    chomp $r;
                    return $r;
                },
            },
            'debug-cat' => {
                cmd_line => 'cat %program',
            }
    );

    my $evalbot_version = get_revision();

    my $regex = $prefix . '(' . join('|',  keys(%impls), keys(%aliases)) . ")$postfix";
    my $format_res = "%s: OUTPUT«%s»\n";
    my $format_nores = "%s: ( no output )\n";

    sub help {
        return "Usage: <$regex \$perl6_program>";
    }
#    warn "Regex: ", $regex, "\n";

    sub format_names {
        my ($names) = @_;
        # Goal: rakudo-{jvm,moar} abcde, rakudo-parrot xyzzy, foo-other
        my %by_rev;
        foreach (@$names) {
            my ($name, $rev) = @$_;
            my ($prefix, $suffix) = ($name, '');
            $name =~ /^(.+?-)(.+)$/
                and ($prefix, $suffix) = ($1, $2);
            push @{$by_rev{$rev}{$prefix}}, $suffix;
        }
        my @combined;
        foreach my $r (sort keys %by_rev) {
            foreach my $p (sort keys %{$by_rev{$r}}) {
                my $s = $by_rev{$r}{$p};
                $s = @$s > 1
                    ? '{' . join(',', @$s) . '}'
                    : $s->[0];
                push @combined, $p . $s . ($r ? " $r" : '');
            }
        }
        return join(', ', @combined);
    }

    sub said {
        my $self = shift;
        my $info = shift;
        my $message = $info->{body};
        my $address = $info->{address} // '';
        return if $info->{who} =~ m/^(dalek|preflex|yoleaux).?$/;
        $message =~ s/␤/\n/g;

        if ($message =~ m/^camelia:/) {
            return "Usage: " . join(',', sort keys %impls) . ': $code';
        } elsif ($message =~ m/\A$regex\s*(.*)\z/s){
            my ($eval_name, $str) = ($1, $2);
            return "Program empty" unless length $str;
            if (ref $aliases{$eval_name}) {
                warn "$info->{channel} <$info->{who}> Perl6: $str\n";
                my %results;
                for my $eval_name (@{ $aliases{$eval_name} }) {
                    my $e = $impls{$eval_name};
                    my $tmp_res = EvalbotExecuter::run($str, $e, $eval_name);
                    $tmp_res =~ s|/tmp/\w{10}|/tmp/tmpfile|g;
                    my $revision = '';
                    if (reftype($e) eq 'HASH' && $e->{revision}){
                        $revision = $e->{revision}->();
                    }
                    push @{$results{$tmp_res}}, [$eval_name, $revision];
                }
                my $result = '';
                while (my ($text, $names) = each %results){
                    $result .= format_output(format_names($names), $text);
                }
                return $result;
            }
            elsif ($aliases{$eval_name}) {
                $eval_name = $aliases{$eval_name}
            }
            my $e = $impls{$eval_name};
            warn "$info->{channel} <$info->{who}> $eval_name: $str\n";
            my $result = EvalbotExecuter::run($str, $e, $eval_name);
            my $revision = '';
            if (reftype($e) eq 'HASH' && $e->{revision}){
                $revision = ' ' . $e->{revision}->();
            }
            my $out = format_output("$eval_name$revision", $result);
            if ($e->{post}) {
                my %extra = $e->{post}->($out);
                for my $k (sort keys %extra) {
                    $out .= " $k: $extra{$k}\n";
                }
            }
            return $out;
        } elsif ( $message =~ m/\Aevalbot\s*control\s+(\w+)/) {
            my $command = $1;
            if ($command eq 'restart'){
                warn "Restarting $0 (by user request)\n";
                # we do hope that evalbot is started in an endless loop ;-)
                exit;
            } elsif ($command eq 'version'){
                return "This is evalbot revision $evalbot_version";
            }
            elsif ($command eq 'pull') {
                return system('git', 'pull', '--quiet')
                    ? '(failed)'
                    : '(success)';
            }
        } elsif ($message =~ m/\Aevalbot\s*rebuild\s+([a-zA-Z0-9_]+)$/) {
            my $name = "$1";
            # XXX We want better integration so that this can go to the right place
            if (EvalbotExecuter::try_lock($name)) {
                system "(./build.pl $name; echo 'freenode #perl6 Rebuild of $name complete.' >> ~/dalek-queue) &";
                return "OK (started asynchronously)";
            } else {
                return "NOT OK (maybe a rebuild is already in progress?)";
            }
        }
        return;
    }

    sub format_output {
        my ($prefix, $response) = @_;

        if (!length $response) {
            return sprintf $format_nores, $prefix;
        }

        my $newline = '␤';
        my $null    = "\N{SYMBOL FOR NULL}";
        $response =~ s/\n/$newline/g;
        $response =~ s/\x00/$null/g;
        $response = IRC::FromANSI::Tiny::convert($response);

        my $format_len = length(encode_utf8(sprintf $format_res, $prefix, ''));
        if (length(encode_utf8($response)) + $format_len > $max_output_len){
            my $target = $max_output_len - 3 - $format_len;
            my $cut_res = '';
            while ($response =~ /(\X)/g) {
                my $grapheme_bytes = encode_utf8($1);
                $target -= length($grapheme_bytes);
                last if $target < 0;
                $cut_res .= $1;
            }
            $response = $cut_res.'…';
        }
        return sprintf $format_res, $prefix, $response;
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

    sub connected {
        my $bot = shift;
        $bot->say(who=>'nickserv',channel=>'msg',body=>"identify $bot->{__nickpass}") if exists $bot->{__nickpass};
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
    print Evalbot::format_output("$eval_name$revision", $result);
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
$bot->{__nickpass} = $conf{pass} if exists $conf{pass};
$bot->run();

# vim: ts=4 sw=4 expandtab
