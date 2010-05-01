package Binary;

use Exporter;
our (@ISA, @EXPORT_OK);
@ISA		= qw(Exporter);
@EXPORT_OK	= qw(bin2dec dec2bin add2bin bin2hex hex2bin hex2binForGIF hex2dec);

sub add2bin($$) {
	my $binary	= shift;
	my $addDicimal	= shift;

	return &dec2bin(&bin2dec($binary) + $addDicimal);
}


# XSにしたい
sub bin2dec($) {
        my $binary      = shift;

        my $decimal     = 0;
        my $figure 	= length $binary;

        foreach (split //, $binary) {
                $decimal += 2 ** $figure if $_;
                $figure--;
        }

	return $decimal / 2;
}

sub dec2bin($) {
	my $decimal	= shift;

	my $binary	= '';
	while ($decimal) {
		$binary		= ($decimal % 2).$binary;
		$decimal	= int $decimal / 2;
	}

	return $binary;
}

sub bin2hex($) {
	my $binary	= shift;

	my $hexadecimal	= '';
	my $rest	= (length $binary) % 4;
	$binary		= '0' x (4 - $rest) . $binary if $rest > 0;

	foreach my $unit ($binary =~ /([01]{4})/g) {
		$hexadecimal	.= unpack("H", pack("B4", $unit));
	}

	return $hexadecimal;
}

sub hex2bin($) {
	my $hexadecimal	= shift;

	my $binary	= '';
	foreach my $unit ($hexadecimal =~ /([0-9a-z]{2})/ig) {
		$binary .= unpack("B8", pack("H2", $unit));
	}

	return $binary;
}

sub hex2binForGIF($) {
	my $hexadecimal = shift;

	my $binary      = '';
	foreach my $unit ($hexadecimal =~ /([0-9a-z]{2})/ig) {
		$binary	= unpack("B8", pack("H2", $unit)).$binary;
	}

	return $binary;
}

sub hex2dec($) {
	my $hexadecimal	= shift;

	return hex($hexadecimal);
}
1;
