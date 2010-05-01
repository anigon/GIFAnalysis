package Euclidean;

use Exporter;
our (@ISA, @EXPORT_OK);
@ISA            = qw(Exporter);
@EXPORT_OK      = qw(getDistance getDistanceUnit);

sub getDistance($$) {
	my $basePoint	= shift;
	my $targetPoint	= shift;

	my ($red, $green, $blue)			= $basePoint =~ /([0-9a-f]{2})/ig;
	my ($targetRed, $targetGreen, $targetBlue)	= $targetPoint =~ /([0-9a-f]{2})/ig;


	return int((&getDistanceUnit($red, $targetRed) +
		&getDistanceUnit($green, $targetGreen) +
		&getDistanceUnit($blue, $targetBlue)) ** 0.5);
}

sub getDistanceUnit($$) {
	my $startPoint  = shift;
	my $endPoint	= shift;

	return (hex($startPoint) - hex($endPoint)) ** 2;
}


1;
