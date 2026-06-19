#!/usr/bin/env perl
use strict;
use warnings;

my $host = $ENV{DEEPIRI_TOMBSTONE_HOST} // '127.0.0.1:11434';
my ($model, $prompt) = @ARGV;
die "usage: http_fallback.pl <model> <prompt>\n" unless defined $model && defined $prompt;

sub json_escape {
    my ($s) = @_;
    $s =~ s/\\/\\\\/g;
    $s =~ s/"/\\"/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\r/\\r/g;
    $s =~ s/\t/\\t/g;
    return $s;
}

my $payload = sprintf(
    '{"model":"%s","prompt":"%s","stream":false}',
    json_escape($model),
    json_escape($prompt)
);

my $cmd = qq{curl -sf "http://$host/api/generate" -d '$payload'};
my $raw = `$cmd`;
die "curl failed\n" if $? != 0;

if ($raw =~ /"response"\s*:\s*"((?:\\.|[^"\\])*)"/s) {
    my $resp = $1;
    $resp =~ s/\\n/\n/g;
    $resp =~ s/\\t/\t/g;
    $resp =~ s/\\r/\r/g;
    $resp =~ s/\\"/"/g;
    $resp =~ s/\\\\/\\/g;
    print $resp;
    exit 0;
}
die "parse failed\n";
