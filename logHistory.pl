#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';

if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

my $HF;

if (@ARGV)
{
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
}
else {$HF = \*STDIN;}

my $count = 0;

while ( my $line = <$HF> )
{
	$count++;
	if ( $line =~ /\d+-\d+ (\S+) \S\/ActivityManager\(\s*\d+\):/ )
	{
		my $time = $1;
		if ( $line =~ /Start proc (\S+) for (\S+) (\S+): pid=(\d+)/ )
		{
			print $count." $1($4) start_$2 $time\n";
		}
		elsif ( $line =~ /Start proc (\S+) for added application (\S+): pid=(\d+)/ )
		{
			print $count." $1($3) start_added_app $time\n";
		}
		elsif ( $line =~ /Start proc (\S+) for content provider (\S+): pid=(\d+)/ )
		{
			print $count." $1($3) start_content_prov. $time\n";
		}
		elsif ( $line =~ /No longer want (\S+) \(pid (\d+)\): hidden #(\d+)/ )
		{
			print $count." $1($2) no_longer $time hidden#$3\n";
		}
		elsif ( $line =~ /Scheduling restart of crashed service (\S+) in (\d+)/ )
		{
			print $count." $1 rescheduling $time $2ms\n";
		}
		elsif ( $line =~ /Process (\S+) \(pid (\d+)\) has died./ )
		{
			print $count." $1($2) died $time\n";
		}
		#invoke INTENT on GB
		elsif ( $line =~ /Starting: Intent { act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+) }/ )
		{
			print $count."    <<<-$1->>> INVOKED $time\n";
		}
		#invoke INTENT on ICS
		elsif ( $line =~ /START {act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+)}/ )
		{
			print $count."    <<<-$1->>> INVOKED $time\n";
		}
	}
}