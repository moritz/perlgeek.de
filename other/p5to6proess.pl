#!/usr/bin/perl
use strict;
use warnings;
#use Pod::Tree::HTML;
use Pod::Simple::HTML;
use File::Slurp qw(slurp);

#my $template = do { local $/; <DATA> };

for my $source (glob 'perl-5-to-6/*.pod'){
    my $dest = $source;
    $dest =~ s{^}{../source/blog-source-en/};
    $dest =~ s{\.pod$}{.txt};
    print $dest, $/;
    my $html;
#    my $parser = Pod::Tree::HTML->new($source, $dest);
#    $parser->translate('template');
    my $parser = Pod::Simple::HTML->new();
    my $pod = slurp($source);
    $pod =~ s/^=head(\d)/'=head' . (2+$1)/meg;
    $parser->set_source(\$pod);
    $parser->output_string(\$html);
    $parser->do_middle();
    my $title = get_title($source);
    open my $d, '>', $dest or die "Can't open '$dest' for writing: $!";
    print $d $title, "\n\n";
    print $d $html;
    print $d "\n", '[% option no-header %] [% option no-footer %]', "\n";
#    $parser->parse_from_file($parser);

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

