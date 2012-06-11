#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';
#use Win32::Console::ANSI;



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
my $maxProcLeng = 40;
my $maxTaskLeng = 18;

my %hProcAdj = (); 		# key is Processname. value is adj.

my @aProc = ();


while ( my $line = <$HF> )
{
	$count++;
	if ( $line =~ /\d+-\d+ (\S+) \S\/ActivityManager\(\s*\d+\):/ )
	{
		my $time = $1;
		my $proc = "";
		my $pid = "";
		my $task = "";
		my $etc = "";
		
		if ( $line =~ /Start proc (.*)$/ )
		{
			#print " !! $1\n";
			$line = $1;
			if ( $line =~ /(\S+) for (\S+) (\S+): pid=(\d+)/ )
			{
				$proc = $1; $pid = $4; $task = "start_$2";				
			}
			elsif ( $line =~ /(\S+) for added application (\S+): pid=(\d+)/ )
			{
				#print $count." $1($3) start_added_app $time\n";
				$proc = $1; $pid = $3; 
				$task = "start_added_app";
			}
			elsif ( $line =~ /(\S+) for content provider (\S+): pid=(\d+)/ )
			{
				#print $count." $1($3) start_content_prov. $time\n";
				$proc = $1; $pid = $3; 
				$task = "start_content_prov.";
			}				
		}

		elsif ( $line =~ /No longer want (\S+) \(pid (\d+)\): hidden #(\d+)/ )
		{
			#print $count." $1($2) no_longer $time hidden#$3\n";
			$proc = $1;
			$pid = $2;
			$task = "no_longer_need";
#			$etc = popPid($pid, $time);
			$etc = removeAdj($proc);
		}
		elsif ( $line =~ /Process (\S+) \(pid (\d+)\) has died./ )
		{
			#print $count." $1($2) died $time\n";
			$proc = $1;
			$pid = $2;
			$task = "died";
#			$etc = popPid($pid, $time);
			$etc = removeAdj($proc);
		}
		elsif ( $line =~ /Scheduling restart of crashed service (\S+) in (\d+)/ )
		{
			#print $count." $1 rescheduling $time $2ms\n";
			$proc = "$1";
			$task = "rescheduling";
			$etc = "$2ms";
		}
		
		#invoke INTENT on GB
#                         Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10200000 cmp=com.google.android.gm/.ConversationListActivityGmail bnds=[123,542][237,686] } from pid 512
		elsif ( $line =~ /Starting: Intent { act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+)/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "->>>$1";
			$task = "INVOKED";
			$etc = "";
		}
		#invoke INTENT on ICS
		elsif ( $line =~ /START {act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+)}/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "->>>$1";
			$task = "INVOKED";
			$etc = "";
		}
		
		# go home on GB
		elsif ( $line =~ /Starting: Intent { act=android.intent.action.MAIN cat=\[android.intent.category.HOME/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "<<<-HOME";
			$task = "GO_HOME";
			$etc = "";
		}
		# go home on ICS
		elsif ( $line =~ /START {act=android.intent.action.MAIN cat=\[android.intent.category.HOME/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "<<<-HOME";
			$task = "GO_HOME";
			$etc = "";
		}
		
		# tracing adj.
		elsif ( $line =~ /Set app (\S+) oom adj to (\S+)/ )
		{
			#print "set ADJ of $1 to $2\n";
			push @aProc, $1 if (!defined($hProcAdj{$1}));
			$hProcAdj{$1} = int($2);
			
			print "$time\t";
			foreach ( @aProc )
			{
				my $adj = $hProcAdj{$_};
				defined($adj) ? printf "%2d ",$hProcAdj{$_} : print "-1 ";
			}
			
			print "\n";
			
			
		}
		
		
	
	}
}

print "time ";
foreach (@aProc)
{
	print "$_ ";
}

#use DateTime::Format::Strptime qw();


sub removeAdj
{	
=cut
	my $return = delete $hProcAdj{$_[0]};	
	$return = defined($return) ? "$_[0]($return) deleted!":"don't know how to delete $_[0]!";
	return $return;
=cut
	defined($hProcAdj{$_[0]}) ? $hProcAdj{$_[0]}=-1 : print "\nSome thing wrong! $_[0]\n";
}