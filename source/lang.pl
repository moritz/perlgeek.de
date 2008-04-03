#!/usr/bin/perl
use warnings;
use strict;

use CGI;
use CGI::Carp qw(fatalsToBrowser);

my $cgi = new CGI;

my $req = $ENV{REDIRECT_URL};
$req = $ENV{REQUEST_URI} unless ($req);

print $cgi->header();

my %de_en = ( 	
# articles
        artikel             => 'article',
        'charsets-unicode'  => 'encodings-and-unicode',
#general:	
		'impressum'	=> 'imprint',
    );


exit unless ($req);

my $lang = "";
if ($req =~ m#^/(de|en)/#){
	$lang = $1;
} else {
	$lang = guess_language();
} 
if (! $lang){
	$lang = "en";
}

my $dest = flip_lang($req, $lang);
if (check_if_url_exists($dest)){
	if ($lang eq "de"){
		print "<a href=\"" , url_encode($dest), "\">English</a> |\n";
	} else {
		print "<a href=\"" , url_encode($dest), "\">Deutsch</a> |\n";
	}
}



sub flip_lang($$){
	my ($req, $lang) = @_;
	$req =~ s#^/(de|en)##;

	my @parts = split m#/#, $req;
	my @translated_parts;
	my %t;
	if ($lang eq "de"){
		%t = %de_en;
	} else {
#		warn "Flipping dictionary";
		%t = reverse %de_en;
	}

	foreach (@parts){
		if ($t{$_}){
			push @translated_parts, $t{$_};
		} else {
			push @translated_parts, $_;
		}
	}
	# A trailing slash does not survive normally, so we need to take extra
	# care:
	if ($req =~ m#/$#){
		$req = join '/', @translated_parts;
		$req .= '/';
	} else {
		$req = join '/', @translated_parts;
	}
#	warn($req);

	if ($lang eq "en"){
		$lang = "de";
	} else {
		$lang = "en";
	}
	return '/' . $lang . $req;
}

##


sub check_if_url_exists {
	my $url = shift;
	return 1 if ($url =~ m#/online/#);
	$url =~ s#^/(de|en)##;
	my $lang = $1;

	if ($url =~ m#/$#){
		# $url refers to a directory
		if (-e $ENV{DOCUMENT_ROOT} . $url . "index.shtml." . $lang){
			return 1;
		}
	} else {
		if (-e $ENV{DOCUMENT_ROOT} . $url . '.shtml.' . $lang){
			return 1;
		}
	}
	return 0;
}

sub guess_language {
	my $l = $ENV{HTTP_ACCEPT_LANGUAGE};
	$l = "" unless ($l);
	my @lang = split /[;,]/, $l;
	foreach (@lang){
		if (m#(de|en)#){
			return $1;
		}
	}
}

sub url_encode {
	my $url = shift;
# warning: disabled url encoding for now until all problems are solved
	$url =~ s/([^\/_A-Za-z0-9-])/sprintf("%%%02X", ord($1))/seg;
	return $url;
}
