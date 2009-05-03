#!/usr/bin/perl
use strict;
use warnings;
use Pod::Simple::HTML;
use File::Slurp qw(slurp);
use Encode qw(encode_utf8 decode_utf8);

for my $source (glob 'perl-5-to-6/*.pod'){
    my $dest = $source;
    $dest =~ s{^}{../source/blog-source-en/};
    $dest =~ s{\.pod$}{.txt};
    print $dest, $/;
    my $timestamp;
    my $html;
    my $parser = Pod::Simple::HTML->new();
    my $pod = decode_utf8(slurp($source));
    if ($pod =~ m/^=for\s+time\s+(\d{5,})/m) {
        $timestamp = $1;
    } else {
        $timestamp = `svn info $source | grep ^Text|cut -d' ' -f 4,5`;
        chomp $timestamp;
        $timestamp = `timestamp $timestamp`;
        chomp $timestamp;
    }
    $pod =~ s/^=head(\d)/'=head' . (2+$1)/meg;
    $parser->set_source(\$pod);
    $parser->output_string(\$html);
    $parser->do_middle();
    my $title = get_title($source);
    open my $d, '>:utf8', $dest or die "Can't open '$dest' for writing: $!";
    print $d $title, "\n";
    print $d "<!-- $timestamp -->\n";
    print $d $html;
    print $d "\n", '[% option no-header %] [% option no-footer %]', "\n";
}

sub get_title {
    my $fn = shift;
    open my $file, '<', $fn or die "Can't open '$fn' for reading: $!";
    while (<$file>) {
        chomp;
        if (m/ - /) {
            return +(split m/ - /, $_, 2)[1];
        }
    }
}

