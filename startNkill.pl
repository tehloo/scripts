#!/usr/bin/perl -w

use strict;
use warnings;

my $repeat_count = 1;
my $sleep_dur = 5;

my $trial =  0;

my $cmd_adbRoot = "adb root";
my $cmd_start	= "adb shell am start -a android.intent.actin.MAIN -n com.lge.e2lab.icshello/.MainActivity";
my $cmd_ps 		= "adb shell ps | grep com.lge.e2lab.icshello";
my $cmd_forceStop 	= "adb shell am force-stop com.lge.e2lab.icshello";

my @out = ();
#@out = `$cmd_adbRoot`;

# 횟수 지정. 없으면 1번
$repeat_count = $ARGV[0] if ($#ARGV == 0);

print " It will runs $repeat_count times...\n\n";
	
while ($trial <$repeat_count)
{	
	# 살아 있으면 죽여놓고.
	check_n_kill();	
	sleep_n_print(7);
	
	print "\n".($trial+1).". ";
	
	# 띄워주죠.
	@out = `$cmd_start`;
	if ($out[0] =~ /Starting/)	{ print "starting... \n"; }
	else { die("\n\nError on starting app!!!\n"); }
	sleep_n_print(2);
	
	$trial++;
}

# 다 끝났으니, 마저 죽여주죠.
check_n_kill();	
print "\n\nFinished...";



sub sleep_n_print
{
	my $sleep_count = $_[0];
	while ($sleep_count--)
	{
		sleep (1);
		print "      (".($sleep_count+1).")\n";
	}
}

sub check_n_kill 
{
	@out = `$cmd_forceStop`;	
	die ("\n\nSomething wrong~!\n") if ($#out > -1);
	print "   ..Killed\n";
}
