#!/usr/bin/perl -w

use strict;
use lib '/home/anigon/binary';
use Binary qw(hex2dec);
use Euclidean qw(getDistance);
use GIFAnalysis;

my $targetFile	= '/home/anigon/binary/' . $ARGV[0];
my $htmlFile	= '/home/anigon/htdocs/euclideanDistance.html';

my $objGIFAnalysis	= GIFAnalysis->new();
if (! defined $objGIFAnalysis->analysis($targetFile)) {
	die("can't analysis file");
}

my $tmp	= join "", @{$objGIFAnalysis->{'_imagePixels'}};
$tmp	=~ s/\n//g;
my $width	= hex($objGIFAnalysis->{'_imageWidth'});
my $height	= hex($objGIFAnalysis->{'_imageHeight'});
my $allPixels	= $width * $height;

open(WR, ">${htmlFile}");

my %colorDistance	= ();
foreach my $color (@{$objGIFAnalysis->{'_globalColorTable'}}) {
	last if ! $color || $color =~ /^$/;
	$colorDistance{$color}{'R'}	= &getDistance('FF0000', $color);
	$colorDistance{$color}{'G'}	= &getDistance('00FF00', $color);
	$colorDistance{$color}{'B'}	= &getDistance('0000FF', $color);
	print WR <<_EOT_;
$color
$colorDistance{$color}{'R'}
$colorDistance{$color}{'G'}
$colorDistance{$color}{'B'}
<br />
_EOT_
}
print WR "<hr />";

my %countColor		= ();
my %sumColorDistance	= ();
foreach my $unit ($tmp =~ /([0-9a-f\-]{6})/ig) {
	$countColor{$unit}++;
}

my $limitRanking	= 10;
my $countRanking	= 0;
foreach my $unit (sort {$countColor{$b} <=> $countColor{$a}} keys %countColor) {
	last if $countRanking > $limitRanking;
	$countRanking++;
print WR "${unit}<font color='#${unit}'>*****</font><br />\n";
	$sumColorDistance{'R'}	+= $colorDistance{$unit}{'R'};
	$sumColorDistance{'G'}	+= $colorDistance{$unit}{'G'};
	$sumColorDistance{'B'}	+= $colorDistance{$unit}{'B'};
}
print WR "<hr />";

print WR int($sumColorDistance{'R'} / $limitRanking);
print WR int($sumColorDistance{'G'} / $limitRanking);
print WR int($sumColorDistance{'B'} / $limitRanking);

close(WR);

exit;

