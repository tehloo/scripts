#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';

use Time::Piece;


# get filename or STDIN via pipe.
if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

# open file 
my $HF;
if (@ARGV) {
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
}
else {
	$HF = \*STDIN;
}


my @broadcastList = ();
my $broadcastHref = 0;
my $count = 0;
my %broadcastHash = ();		# make hash, not only href

my $startIntent = "android.intent.action.USER_BACKGROUND";
#my $endIntent = "android.intent.action.USER_SWITCHED";
#my $endIntent = "android.intent.action.USER_STOPPED";
my $endIntent = "android.intent.action.BOOT_COMPLETED";

my $bStarted = 0;


# read line by line
while ( my $line = <$HF> )
{
	$count++;
	
	last if ($bStarted == 2);
	
	if ( $line =~ /\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sBroadcastQueue:(.*)$/ ) {
	
		my $time = $1;
		my $proc = "";
		my $pid = "";
		my $task = "";
		my $etc = "";
		
#		print $line;
#		print $1." / ".$2."\n";

		if ( $2 =~ /Processing ordered broadcast \[\S+\] BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryStart', 'ordered', $2);
			
		} elsif ( $2 =~ /Finished with ordered broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryFinish', 'ordered', $2);
			
			if ($2 eq $endIntent) {
				print "!!! ends at $count\n";
				$bStarted = 2;
			}

		} elsif ( $2 =~ /Processing parallel broadcast \S+ BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryStart', 'parallel', $2);			
		
		} elsif ($2 =~ /Done with parallel broadcast \S+ BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryFinish', 'parallel', $2);
			
			if ($2 eq $endIntent) {
				print "!!! ends at $count\n";
				$bStarted = 2;
			}

		} elsif ( $2 =~ /Delivering to BroadcastFilter\{\S+ u\S+ ReceiverList\{\S+ \S+ \S+ \S+\}\} \(\S+\): BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			addReceiverCount($1);

		} elsif ( $2 =~ /Process cur broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\} DELIVERED for app (.*)/) {
			print $line;
			addReceiverCount($1);
		}

	} elsif ( $line =~ /\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sActivityManager:(.*)$/ ) {
		my $time = $1;

#		print $1." / ".$2."\n";
#			      /Enqueueing ordered broadcast BroadcastRecord{43048978 u-1 android.intent.action.USER_STARTING}: prev had 0
		if ($2 =~ /Enqueueing (\S+) broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			my $type = $1;
			my $uid = $2;
			my $intent = $3;
			
			if ($intent eq $startIntent) {
				$bStarted = 1;
				print "!!! started at $count\n";
			}
			
			if ($bStarted > 0) {
#				print $line;
				makeIntent($type, $uid, $intent, $time);			
			}
		}
	}
}

sub updateIntent {
			my $uid = $_[0];
			my $time = $_[1];
			my $field = $_[2];
			my $type = $_[3];
			my $intent = $_[4];
			
			if (exists $broadcastHash{$uid}) {
#				print "EXIST!\n";
				my $href = $broadcastHash{$uid};
				if ($href->{'type'} eq $type) {
					$href->{$field} = $time;
				} else {
					print "NOT EXIST!!!! intent $uid/ $field for $intent ($count)\n";
				}
				
#				print " $field = $href / $uid / $time/ $href->{'deliveryFinish'}\n";
			} else {
				print "NOT EXIST! intent $uid/ $field for $intent ($count)\n";
			}
}

sub addReceiverCount {
			my $uid = $_[0];
			
			if (exists $broadcastHash{$uid}) {
#				print "EXIST!\n";
				my $href = $broadcastHash{$uid};
				my $addVal = $href->{'receiverCount'};
				$href->{'receiverCount'} = $addVal + 1;
				
#				print " receiverCount= $href->{'receiverCount'}\n";
			} else {
				print "NOT EXIST! receiver $uid\n";
			}
}

sub makeIntent {
#			print $1." / ".$2."\n";
			my $type = $_[0];
			my $uid = $_[1];
			my $intent = $_[2];
			my $time = $_[3];
			
			my %pBroadcast = (
					uid => $uid,
					intent => $intent,
					type => $type,
					enqueueTime => $time,
					deliveryStart => "0",
					deliveryFinish => "0",
					receiverCount => 0
					);
			$broadcastHref = \%pBroadcast;
			$broadcastHash{$uid} = $broadcastHref;
			push @broadcastList, $uid;			
			
#			print "enqueue ... %pBroadcast\n";
}


# scan and summary!
my %hash_IntentType = ();

print "\n\n  ==== show all Intents ====\n\n";

foreach my $uid ( @broadcastList ) {
	if (exists $broadcastHash{$uid}) {
		my $href = $broadcastHash{$uid};		
		my $intent = $href->{'intent'};
		my $deliveryStart = $href->{'deliveryStart'};
		my $type = $href->{'type'};
		my $enqueueTime = $href->{'enqueueTime'};
		my $deliveryFinish = $href->{'deliveryFinish'};
		my $receiverCount = $href->{'receiverCount'};
		
		if (exists $hash_IntentType{$intent}) {
			$hash_IntentType{$intent} = $hash_IntentType{$intent} + 1;
		} else {
			$hash_IntentType{$intent} = 1;
		}
		
		
		printIntent($href, "\t") if ($deliveryStart ne 0);
		
		
#print "$intent\n";
	} else {
		print "!!!NOT EXIST! $uid\n";
	}
}

print "\n\n  ==== count all Intents ====\n\n";
printHash(\%hash_IntentType, "\n");

sub printIntent {
	my $href = $_[0];	
	my $intent = $href->{'intent'};
	my $deliveryStart = $href->{'deliveryStart'};
	my $type = $href->{'type'};
	my $enqueueTime = $href->{'enqueueTime'};
	my $deliveryFinish = $href->{'deliveryFinish'};
	my $receiverCount = $href->{'receiverCount'};
=cut	
	my $dt_queue = Time::Piece->strptime($enqueueTime, "%H:%M:%S.A%3N");
	my $dt_start = Time::Piece->strptime($deliveryStart, "%H:%M:%S.A%3N");
	my $dt_fin = Time::Piece->strptime($deliveryFinish, "%H:%M:%S.A%3N");
=cut	
	print " $type\t$intent\t$receiverCount\t$enqueueTime\t$deliveryStart\t$deliveryFinish\n";
}

sub printHash {
	my $hash_ref = $_[0];
	my $delimeter = $_[1];
#	print "%".$hash_ref."\n";
	while ( my ($key, $value) = each %$hash_ref) {
		print " $key=$value$delimeter";
	}
	print "\n";
}



