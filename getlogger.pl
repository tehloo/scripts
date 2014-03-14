#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'strftime';

my $PREFIX_ADB_PULL = "adb pull /data/";
my $logPath;
my @out;

if ($#ARGV == 0) {
	$logPath = $ARGV[0];
} else {
	$logPath = strftime('%Y%m%d_%H%M%S', localtime);
}

print "\n\n It get logs and dumps to $logPath...\n\n";

adb_pull("anr");
adb_pull("dontpanic");
adb_pull("logger");
adb_pull("tombstones");

sub adb_pull {
	my $cmd = $PREFIX_ADB_PULL.$_[0]." ".$logPath."/".$_[0];
	print " - Pulling $_[0]...\n";
	@out = `$cmd`;
	print "\n\n"
#	print " result\n".@out;
}