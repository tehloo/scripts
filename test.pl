#!/usr/bin/perl -w

use strict;
use warnings;

my @a1 =();
my @a2 =();
$a1[5][4] = "haha";
$a1[10][10] = "gg";
$a1[10][9] = "haha";
print $a1[10][10];
printf "\n";
print $#a1;
print $#a2;
printf "\n".$#{$a1[10]};
printf "\n".$#{$a1[5]};
printf "\n".$#{$a1[5]};
