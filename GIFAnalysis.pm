package GIFAnalysis;

use strict;
use lib '/home/anigon/binary';
use Binary qw(bin2dec dec2bin add2bin hex2bin hex2dec hex2binForGIF);

my $GIF_SIGNATURE		= '474946';
my $GIF_VERSION_87A		= '383761';
my $GIF_VERSION_89A		= '383961';
my $GRAPHIC_CONTROL_EXTENSION	= '21F904';
my $MIN_CODE_SIZE		= 3;
my $IMAGE_BLOCK			= '2C';
my $IMAGE_BLOCK_TERMINATOR	= '003B';

sub new {
	my $me	= shift;
	bless {}, $me;
}

sub analysis {
	my $me		= shift;
	my $filePath	= shift;

	return 0 if $me->_getAllDataAsHex($filePath) == 0;
	
	$me->_setGIFHeaderData();
	$me->_getTransparentColor();
	$me->_setTransparentColor();
	$me->_setImageBlockData();
	$me->_decodeImageData();

	return 1;
}

sub _setTransparentColor {
	my $me		= shift;

	return if ! defined $me->{'_transparentColor'};

	my $index	= &hex2dec($me->{'_transparentColor'});
	$me->{'_globalColorTable'}->[$index]	= '------';
}

# read data & save data as hex into _allImageHex
sub _getAllDataAsHex {
	my $me		= shift;
	my $filePath	= shift;

	return 0 unless (open(IN, $filePath));
	binmode IN;

	my $tmpValue	= '';
	while (read (IN, $tmpValue, 1)) {
		$me->{'_allImageHex'}	.= unpack("H2", $tmpValue);
	}

	return 1;
}

sub _setGIFHeaderData {
	my $me		= shift;

	$me->{'_allImageHex'} =~ s/${GIF_SIGNATURE}(?:$GIF_VERSION_87A|$GIF_VERSION_89A)
					([0-9a-f]{4})([0-9a-f]{4})	# width, height
					([0-9a-f]{2})			# packed field
					[0-9a-f]{4}			# Background Color Index
				//xi;
	my ($width, $height, $packed)	= ($1, $2, $3);
	$me->{'_screenWidth'}		= $me->_getLittleEndian($width);
	$me->{'_screenHeight'}		= $me->_getLittleEndian($height);

	my %tmpHash	= ();
	$me->_setBitDataFromPackedField($packed, \%tmpHash, 'GIFHeader');

	$me->{'_sizeOfGlobalColorTable'} 	= ($tmpHash{'flag'}) ? (2 ** $tmpHash{'sizeOfColorTable'}) * 3 * 2: 0;
	#$me->{'_codeSize'}			= &bin2dec($tmpHash{'colorResolution'}) + 1;
	#$me->{'_codeSize'}			= $MIN_CODE_SIZE if $me->{'_codeSize'} < $MIN_CODE_SIZE;

	$me->{'_allImageHex'} 	=~ s/^([0-9a-f]{$me->{'_sizeOfGlobalColorTable'}})//i;
	my $globalColor		= $1;

	$me->_setColorTable(\$globalColor, '_globalColorTable');
}

sub _setColorTable {
	my $me		= shift;
	my $refColor	= shift;
	my $keyOfHash	= shift;

	my $dicNo		= 0;
	foreach my $color ($$refColor =~ /([0-9a-f]{6})/ig) {
		$me->{$keyOfHash}->[$dicNo]	= $color;
		$dicNo++;
	}
}

sub _getTransparentColor {
	my $me		= shift;

	my ($all, $packed, $transparentColor)	= 
	$me->{'_allImageHex'}		=~ /(${GRAPHIC_CONTROL_EXTENSION}
						([0-9a-f]{2})[0-9a-f]{4}
						([0-9a-f]{2})00)
		 			/ix;
	$me->{'_allImageHex'}		=~ s/${all}//;

        my $binary	= &hex2bin($packed);
        my ($flag)	= $binary =~ /^[01]{7}([01])/;

	$me->{'_transparentColor'}	= $transparentColor if $flag;
} 

sub _setImageBlockData {
	my $me		= shift;

	my ($all, $left, $top, $width, $height, $packed)	= 
		$me->{'_allImageHex'}	=~ /(${IMAGE_BLOCK}
						([0-9a-f]{4})([0-9a-f]{4})
						([0-9a-f]{4})([0-9a-f]{4})
						([0-9a-f]{2}))
					/ix;

	$me->{'_imageLeftPosition'}	= $me->_getLittleEndian($left);
	$me->{'_imageTopPosition'}	= $me->_getLittleEndian($top);
	$me->{'_imageWidth'}		= $me->_getLittleEndian($width);
	$me->{'_imageHeight'}		= $me->_getLittleEndian($height);

	my %tmpHash	= ();
	$me->_setBitDataFromPackedField($packed, \%tmpHash);
	$me->{'_sizeOfLocalColorTable'} = ($tmpHash{'flag'}) ? (2 ** $tmpHash{'sizeOfColorTable'}) * 3 * 2 : 0;

	my ($tmpAll, $localCcolor, $LZWMin, $blockSize)
		= $me->{'_allImageHex'}
		=~ /
			(${all}
			([0-9a-f]{$me->{'_sizeOfLocalColorTable'}})
			([0-9a-f]{2})
			([0-9a-f]{2}))
		/ix;

	$me->_setColorTable(\$localCcolor, '_localColorTable') if $localCcolor;
	$me->_setImageData($LZWMin, $blockSize, \$tmpAll);
}

sub _setImageData {
	my $me			= shift;
	my $LZWMin		= shift;
	my $blockSize		= shift;
	my $refStartSymbol	= shift;

	my $decBlockSize	= &hex2dec($blockSize) * 2;
	$me->{'_blockSize'}	= $decBlockSize;
	($me->{'_imageData'})
				= $me->{'_allImageHex'}
				=~ /
					${$refStartSymbol}
					([0-9a-f]*)
					003b
				/ix;


	my $decimalCC		= 2 ** &hex2dec($LZWMin);
	$me->{'_CC'}		= &dec2bin($decimalCC);	# ｿｿｿｿｿｿｿｿｿｿNG
	$me->{'_EOI'}		= &add2bin($me->{'_CC'}, 1);
	$me->{'_nextCode'}	= $decimalCC + 2;
	$me->{'_codeSize'}	= length $me->{'_CC'};
	$me->{'_maxSize'}	= 2 ** $me->{'_codeSize'};

	delete $me->{'_allImageHex'};
}


sub _decodeImageData {
	my $me		= shift;

	$me->{'_isFirstPixel'}		= 0;
	$me->{'_firstDicNo'}		= $me->{'_nextCode'};
	$me->{'_firstCodeSize'}		= $me->{'_codeSize'};
	$me->{'_firstMaxSize'}		= $me->{'_maxSize'};

	my $targetBinary	= '';
	my $rest		= '';

	while ($me->{'_imageData'}) {
		$me->{'_imageData'}	=~ s/^([0-9a-f]{$me->{'_blockSize'}})//i;
		$targetBinary	= $1;
		$targetBinary	= &hex2binForGIF($targetBinary);

		$rest	= $me->_decodeImageDataDetail("${targetBinary}${rest}");
		last if $me->{'_imageData'} !~ /[0-9a-f]{2}$/i;

		$me->{'_imageData'}     =~ s/^([0-9a-f]{2})//i;
		$me->{'_blockSize'}	= &hex2dec($1) * 2;
	}

}

sub _initDicColorTable {
	my $me			= shift;

	delete @{$me->{'_globalColorTable'}}[$me->{'_firstDicNo'}..$me->{'_nextCode'}];

	$me->{'_nextCode'}	= $me->{'_firstDicNo'};
	$me->{'_codeSize'}	= $me->{'_firstCodeSize'};
	$me->{'_maxSize'}	= $me->{'_firstMaxSize'};
	$me->{'_isFirstPixel'}	= 1;
}

sub _decodeImageDataDetail {
	my $me			= shift;
	my $targetBinary	= shift;

	my $decimal	= '';
	my $unit	= '';

	while ($targetBinary) {
		last if $targetBinary =~ /^0*$me->{'_EOI'}$/;
		last if $targetBinary eq '';

		$targetBinary	=~ s/([01]{$me->{'_codeSize'}})$//;
		$unit		= $1;
		last if $unit !~ /^[01]*$/;

		if ($unit =~ /^0*$me->{'_CC'}$/) {
			$me->_initDicColorTable();
			next;
		}

		$decimal	= &bin2dec($unit);
		if ($me->{'_isFirstPixel'}) {
			$me->_setFirstPixel($decimal);
			next;
		}

		# -----------------------------------------------------------------
		# -- this routine shuld not be a sub routine, it's will be too slowly.
		if (! defined $me->{'_globalColorTable'}->[$decimal] ||
				$me->{'_globalColorTable'}->[$decimal] eq '') {
			$me->{'_candidate'}	= $me->{'_buffer'}.substr($me->{'_lastUnit'}, 0, 6);
			$me->{'_buffer'}	= $me->{'_candidate'};
		} else {
			$me->{'_candidate'}	= $me->{'_buffer'}.substr($me->{'_globalColorTable'}->[$decimal], 0, 6);
			$me->{'_buffer'}	= $me->{'_globalColorTable'}->[$decimal];
		}

		push @{$me->{'_imagePixels'}}, $me->{'_buffer'};
		# -----------------------------------------------------------------

		$me->{'_globalColorTable'}->[$me->{'_nextCode'}]	= $me->{'_candidate'};
		$me->{'_lastUnit'}					= $me->{'_globalColorTable'}->[$decimal];
		$me->{'_nextCode'}++;

		next if $me->{'_codeSize'} >= 12;
		next if $me->{'_nextCode'} < $me->{'_maxSize'};

		$me->_incrementCodeSize();
	}

	return "$targetBinary";
}

sub _setFirstPixel {
	my $me		= shift;
	my $decimal	= shift;

	my $firstDic	= $me->{'_globalColorTable'}->[$decimal];

	push @{$me->{'_imagePixels'}}, $firstDic;

	$me->{'_buffer'}	= $firstDic;
	$me->{'_lastUnit'}	= $firstDic;
	$me->{'_isFirstPixel'}	= 0;
}

sub _incrementCodeSize {
	my $me		= shift;

	$me->{'_codeSize'}++;
	$me->{'_maxSize'}	= 2 ** $me->{'_codeSize'};
}

sub _getLittleEndian($) {
	my $me		= shift;
	my $string	= shift;

	$string		=~ /^(.{2})(.{2})$/;

	return "$2$1";
}

# 使ってないけど、残しておきたい
sub _getReverseColor {
	my $me			= shift;
	my $color		= shift;

	my $reverseOct		= 16777215 - int(hex($color));
	return sprintf("%06X", $reverseOct);
}

# 使用中
sub _setBitDataFromPackedField {
	my $me		= shift;
	my $value	= shift;
	my $refHash	= shift;
	my $isGIFHeader	= shift || 0;

	my $binary	= &hex2bin($value);
	my ($flag, $colorResolution, $sizeOfColorTable)	
			= $binary =~ /^(1|0)([01]{3})[01]([01]{3})/;

	$refHash->{'flag'}		= $flag;
	$refHash->{'colorResolution'}	= $colorResolution if $isGIFHeader;
	$sizeOfColorTable		= unpack("C*", pack("B*", '00000' . $sizeOfColorTable)) + 1;
	$refHash->{'sizeOfColorTable'}	= $sizeOfColorTable;
}


1;
# end of this class
