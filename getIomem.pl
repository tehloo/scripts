#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';
use GD::Simple;

my $bDebug = 1;

my @label = ();
#my %hexStart = ();
#my %hexEnd = ();
my @hexStart = ();
my @hexEnd = ();
my $index = 0;

# define for graph.
my $height = 2000;
my $width = 100;
my $startX = 20;
my $startY = 20;


# array for rectangles.
my @rects = ();


getRawdata();
getLabel() if ($bDebug>0);
makeArray();
getCordinate() if ($bDebug>0);
drawBoxes() if ($bDebug==0);


sub makeArray
{
	my $i = 0;
	my $iRect = 0;
	my $prevEnd = 0;

	my $totalLen = hex($hexEnd[$#label]);		#	set last address as length.
	my $ratio = $totalLen / $height;			#	it will be devided to each height of sections.
	
	foreach (@label)
	{
		my $start = hex($hexStart[$i]) / $ratio;
		my $end = hex($hexEnd[$i]) / $ratio;
			
		if ($prevEnd > $end)
		{
			$i++;
			next;
		} 
		
		$rects[$iRect][0] = $startX;
		$rects[$iRect][1] = $startY+$start;
		$rects[$iRect][2] = $startX+$width;
		$rects[$iRect][3] = $startY+$end;
		$rects[$iRect][4] = $_;

#		print $rects[$iRect][0].", ".$rects[$iRect][1].", ".$rects[$iRect][2].", ".$rects[$iRect][3]." - ".$label[$i]."\n";
		
		$prevEnd = $end;
		$i++;
		$iRect++;
	}
}



sub drawBoxes
{
	my $img = GD::Simple->new($width+$startX*2+100 ,$height+$startY*2);
	my $i = 0;
	# border
	$img->rectangle($startX,$startY,$startX+$width,$startY+$height);
	$img->bgcolor('gray');
	foreach (@rects) {
		$img->rectangle($$_[0],$$_[1],$$_[2],$$_[3]);
		$img->moveTo($$_[0]+$width/10, $$_[1]+($$_[3]-$$_[1])/2);
		$img->string($$_[4]);
	}    
	binmode STDOUT;	
	print $img->png;
}

sub getRawdata
{
	`adb root`;
	my @output = `adb shell cat /proc/iomem`;
#	print "--------\n";
#	print @output;
#	print "--------\n";
	
	foreach ( @output )
	{
		if ( $_ =~ /(\S+)-(\S+)\s:\s(.+)$/ )
		{
			next if ( $_ =~ /^\s*a.+/ );
			
#			print $1." ".$2." ".$3."\n";
			push @label, $3;
			#$hexStart{$3} 	= $1;
			#$hexEnd{$3} 	= $2;
			push @hexStart, $1;
			push @hexEnd, $2;
		}
	}
}

#for examine.
sub getLabel
{
	foreach (@label){
		print $hexStart[$index]." ~ ".$hexEnd[$index].":".$_."\n";
		$index++;
	}
}

sub getCordinate
{
	foreach (@rects) {
		print $$_[0].",".$$_[1].",".$$_[2].",".$$_[3]." - ".$$_[4]."\n";
	}  
}