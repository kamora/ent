#!/usr/bin/perl
# Canon 003: a multi-line comment (a /* */ block, or two or more consecutive // or /// lines) gets an empty
# line above it, except on the first line of a file and, in Dart, right after `{`, where dart format leaves
# none (canon 006). tool/format.sh runs this after dart format. Usage: perl tool/comment_spacing.pl file.dart ...
use strict;
use warnings;

for my $file (@ARGV) {
	open(my $in, '<', $file) or die "$file: $!";
	my @lines = <$in>;
	close($in);

	my @out;

	for my $i (0 .. $#lines) {
		my $line = $lines[$i];
		my $starts = $line =~ m{^\s*//} && ($i == 0 || $lines[$i - 1] !~ m{^\s*//});
		my $multi = ($starts && $i < $#lines && $lines[$i + 1] =~ m{^\s*//}) || $line =~ m{^\s*/\*};

		if ($multi && $i > 0 && $lines[$i - 1] !~ /^\s*$/ && $lines[$i - 1] !~ /\{\s*$/) {
			push @out, "\n";
		}

		push @out, $line;
	}

	open(my $out, '>', $file) or die "$file: $!";
	print $out @out;
	close($out);
}
