#!/usr/bin/perl -w

use strict;
use warnings;
use Cwd 'abs_path';

# if a argument has given, it will be the path of log files.
my $path = ($#ARGV == 0)? $ARGV[0]:"logger";
my @logfiles = ();

# build array only for MainLog.
sub getFilename 
{
	opendir(dirHandle, $path) || die "Failed to open. check the path : \\$path";
	my @files = readdir( dirHandle );	# get every files from dirHandle.
	closedir dirHandle;  # ²À ´ÝÀ¾...
=cut
	# get MainLog files and push to logfiles array.
	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /main\.log.*/);
	}

	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /events\.log.*/);
	}
=cut

	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /system\.log.*/);
	}
}
getFilename();
print "$#logfiles files found to parse.\n";
print "$_\n" foreach(@logfiles);
