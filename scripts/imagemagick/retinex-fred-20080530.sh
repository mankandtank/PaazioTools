#!/bin/bash
# 
# Developed by Fred Weinhaus 11/15/2007 .......... revised 1/29/2008
# 
# USAGE: retinex [-m colormodel] [-f fact] [-c contrast] [-b bright] [-s sat] [-r res1,res2,res3] infile outfile
# USAGE: retinex [-h or -help]
# 
# OPTIONS:
# 
# -m      colormodel          processing colorspace; HSL or RGB; default=HSL
# -f      fact                color boost blending factor; 0 - 100; default=0
#                             0 is no color boost; 100 is full color boost
# -c      contrast            contrast gamma; contrast>0; default=1 (no change)
# -b      bright              brightness gain; bright>=0; default=100 (no change)
# -s      sat                 saturation gain; sat>=0; default=100 (no change)
# -r      res1,res2,res3      resolution levels; default=5,20,240
# 
###
# 
# NAME: RETINEX
# 
# PURPOSE: To enhance detail and color in an image using the multiscale 
# retinex algorithm.
# 
# DESCRIPTION: RETINEX converts the intensity values in the image to
# reflectance values at three resolution scales. This is achieved by
# computing the log of the ratio of the image to each of three gaussian
# blurred version of the image; one slightly blurred, one moderately
# blurred and one severely blurred. The three results are then averaged
# together. As this process sometimes desaturates the image an optional
# color boost is provided. The color boost process creates a new image
# which is the product of the resulting image with the log of the ratio of
# the original image to its grayscale version. The color boosted image is
# then blended with the previous result. The basic processing operation 
# prior to the color boost can be performed in RGB colorspace in order to 
# process each channel separately or it can be performed only on the 
# lightness channel in HSL colorspace. The latter may be prefered as 
# it tends to maintain the color balance from the original image. The 
# implementation of this script adapts the retinex approach developed 
# by NASA/Truview. See the following references:
# http://dragon.larc.nasa.gov/retinex/background/pubabs/papers/ret40.pdf
# http://visl.technion.ac.il/1999/99-07/www/
# http://dragon.larc.nasa.gov/retinex/
# http://www.truview.com/
# 
# 
# OPTIONS: 
# 
# -m colormodel ... COLORMODEL can be either RGB or HSL. If RGB is 
# selected, then each of the R, G and B channels will be processed 
# independently (possibly causing a color shift). If HSL is selected, 
# then only the Lightness channel will be processed and then recombined 
# with the Hue and Saturation channels and converted back to RGB. This 
# option may be preferred as it will better maintain the relative color 
# balance from the original image. The default is HSL.
# 
# -f fact ... FACT specifies the color boost blending percentage. Values 
# for fact may be an integer between 0 and 100. A value of 0 indicates no 
# color boost. A value of 100 indicates full color boost. The default=0
# 
# -c contrast ... CONTRAST specifies a gamma control for contrast. Values 
# for contrast must be positive floats or integers. A value of 1 indicates 
# no contrast change. Larger/smaller values indicate lower/higher contrast.
# 
# -b bright ... BRIGHT specifies a gain in brightness. Values for bright 
# must be non-negative integers. A value of 100 indicates no brightness 
# change. Larger/smaller values indicate brighter/darker results.
# 
# -s sat ... SAT specifies a gain in saturation. Values for sat 
# must be non-negative integers. A value of 100 indicates no saturation 
# change. Larger/smaller values indicate more/less saturation.
# 
# -r res1,res2,res3 ... RES1,RES2,RES3 specifies the three resolution 
# levels in the retinex processing. They correspond to the pixel 
# equivalent values to the sigma in the Gaussian blurring. These 
# resolution values do not seem to be very sensitive such that 
# variations to do not seem to make much change in the result. 
# The default values are 5,20,240.
# 
# Due to the use of -fx, this script may be a little slow.
# 
# CAVEAT: No guarantee that this script will work on all platforms, 
# nor that trapping of inconsistent parameters is complete and 
# foolproof. Use At Your Own Risk. 
# 
######
#

# set default values
colormodel="HSL"	# colorspace in which to process image
fact=0          	# color boost blending factor
contrast=1      	# contrast control (gamma value)
bright=100      	# brightness control
sat=100         	# saturation conrol
res=5,20,240    	# resolution sizes

# set directory for temporary files
dir="."    # suggestions are dir="." or dir="/tmp"

# set up functions to report Usage and Usage with Description
PROGNAME=`type $0 | awk '{print $3}'`  # search for executable on path
PROGDIR=`dirname $PROGNAME`            # extract directory of program
PROGNAME=`basename $PROGNAME`          # base name of program
usage1() 
	{
	echo >&2 ""
	echo >&2 "$PROGNAME:" "$@"
	sed >&2 -n '/^###/q;  /^#/!q;  s/^#//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
	}
usage2() 
	{
	echo >&2 ""
	echo >&2 "$PROGNAME:" "$@"
	sed >&2 -n '/^######/q;  /^#/!q;  s/^#*//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
	}


# function to report error messages
errMsg()
	{
	echo ""
	echo $1
	echo ""
	usage1
	exit 1
	}


# function to test for minus at start of value of second part of option 1 or 2
checkMinus()
	{
	test=`echo "$1" | grep -c '^-.*$'`   # returns 1 if match; 0 otherwise
    [ $test -eq 1 ] && errMsg "$errorMsg"
	}

# test for correct number of arguments and get values
if [ $# -eq 0 ]
	then
	# help information
   echo ""
   usage2
   exit 0
elif [ $# -gt 14 ]
	then
	errMsg "--- TOO MANY ARGUMENTS WERE PROVIDED ---"
else
	while [ $# -gt 0 ]
		do
			# get parameter values
			case "$1" in
		  -h|-help)    # help information
					   echo ""
					   usage2
					   exit 0
					   ;;
				-m)    # get colormodel
					   shift  # to get the next parameter - colormodel
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID COLORMODEL SPECIFICATION ---"
					   checkMinus "$1"
					   # test mask values
					   colormodel="$1"
					   [ "$colormodel" != "RGB" -a "$colormodel" != "HSL" -a "$colormodel" != "rgb" -a "$colormodel" != "hsl" ] && errMsg "--- COLORMODEL=$colormodel IS NOT A VALID VALUE ---"
					   ;;
				-f)    # get fact for color boost
					   shift  # to get the next parameter - fact
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID FACT SPECIFICATION ---"
					   checkMinus "$1"
					   # test fact values
					   fact=`expr "$1" : '\([0-9]*\)'`
					   [ "$fact" = "" ] && errMsg "FACT=$fact IS NOT A NON-NEGATIVE INTEGER"
		   			   facttestA=`echo "$fact < 0" | bc`
		   			   facttestB=`echo "$fact > 100" | bc`
					   [ $facttestA -eq 1 -o $facttestB -eq 1 ] && errMsg "--- FACT=$fact MUST BE GREATER THAN OR EQUAL 0 AND LESS THAN OR EQUAL 100 ---"
					   ;;
				-c)    # get contrast
					   shift  # to get the next parameter - contrast
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID CONTRAST SPECIFICATION ---"
					   checkMinus "$1"
					   # test contrast values
					   contrast=`expr "$1" : '\([.0-9]*\)'`
					   [ "$contrast" = "" ] && errMsg "CONTRAST=$contrast IS NOT A NON-NEGATIVE FLOAT"
		   			   contrasttestA=`echo "$contrast <= 0" | bc`
					   [ $contrasttestA -eq 1 ] && errMsg "--- CONTRAST=$contrast MUST BE GREATER THAN 0 ---"
					   ;;
				-b)    # get bright
					   shift  # to get the next parameter - bright
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID BRIGHT SPECIFICATION ---"
					   checkMinus "$1"
					   # test bright values
					   bright=`expr "$1" : '\([0-9]*\)'`
					   [ "$bright" = "" ] && errMsg "BRIGHT=$bright IS NOT A NON-NEGATIVE INTEGER"
		   			   brighttestA=`echo "$bright < 0" | bc`
					   [ $brighttestA -eq 1 ] && errMsg "--- BRIGHT=$bright MUST BE GREATER THAN OR EQUAL 0 ---"
					   ;;
				-s)    # get sat
					   shift  # to get the next parameter - sat
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID SAT SPECIFICATION ---"
					   checkMinus "$1"
					   # test sat values
					   sat=`expr "$1" : '\([0-9]*\)'`
					   [ "$sat" = "" ] && errMsg "SAT=$sat IS NOT A NON-NEGATIVE INTEGER"
		   			   sattestA=`echo "$fact < 0" | bc`
					   [ $sattestA -eq 1 ] && errMsg "--- SAT=$sat MUST BE GREATER THAN OR EQUAL 0 ---"
					   ;;
				-r)    # get res
					   shift  # to get the next parameter - res
					   # test if parameter starts with minus sign 
					   errorMsg="--- INVALID RES SPECIFICATION ---"
					   checkMinus "$1"
					   # test sat values
					   res=`expr "$1" : '\([0-9]*,[0-9]*,[0-9]*\)'`
					   [ "$res" = "" ] && errMsg "RES=$res IS NOT A SET OF 3 COMMA SEPARATED NON-NEGATIVE INTEGERS"
					   ;;
 				 -)    # STDIN, end of arguments
  				 	   break
  				 	   ;;
				-*)    # any other - argument
					   errMsg "--- UNKNOWN OPTION ---"
					   ;;					   
		     	 *)    # end of arguments
					   break
					   ;;
			esac
			shift   # next option
	done
	#
	# get infile and outfile
	infile=$1
	outfile=$2
fi


# test that infile provided
[ "$infile" = "" ] && errMsg "NO INPUT FILE SPECIFIED"

# test that outfile provided
[ "$outfile" = "" ] && errMsg "NO OUTPUT FILE SPECIFIED"

tmpA="$dir/retinex_$$.mpc"
tmpB="$dir/retinex_$$.cache"
tmpH="$dir/retinex_H_$$.png"
tmpS="$dir/retinex_S_$$.png"
tmp0="$dir/retinex_0_$$.png"
tmp1="$dir/retinex_1_$$.png"
tmp2="$dir/retinex_2_$$.png"
tmp3="$dir/retinex_3_$$.png"
trap "rm -f $tmpA $tmpB $tmpH $tmpS $tmp0 $tmp1 $tmp2 $tmp3; exit 0" 0
trap "rm -f $tmpA $tmpB $tmpH $tmpS $tmp0 $tmp1 $tmp2 $tmp3; exit 1" 1 2 3 15

if convert -quiet -regard-warnings "$infile" +repage "$tmpA"
	then
	if [ "$colormodel" = "HSL" -o "$colormodel" = "hsl" ]
		then
		# save original
		convert $tmpA $tmp0
		# convert to HSL reusing $tmpA for Lightness
		convert $tmpA -colorspace HSL -channel R -separate $tmpH
		convert $tmpA -colorspace HSL -channel G -separate $tmpS
		convert $tmpA -colorspace HSL -channel B -separate $tmpA
	fi
else
	errMsg "--- FILE $infile DOES NOT EXIST OR IS NOT AN ORDINARY FILE, NOT READABLE OR HAS ZERO SIZE ---"
fi

# process image
echo ""
echo "Please Wait - It May Take Some Time To Process The Image"
echo ""

# get 3 resolution sizes
res1=`echo "$res" | cut -d, -f1`
res2=`echo "$res" | cut -d, -f2`
res3=`echo "$res" | cut -d, -f3`

# create reflectance images at each resolution size
convert $tmpA \( +clone -blur 0x$res1 \) -fx "log((u/max(v,.000001))+1)" $tmp1
convert $tmpA \( +clone -blur 0x$res2 \) -fx "log((u/max(v,.000001))+1)" $tmp2
convert $tmpA \( +clone -blur 0x$res3 \) -fx "log((u/max(v,.000001))+1)" $tmp3

# average results (normalize as log reduces range of values)
convert $tmp1 $tmp2 $tmp3 -average -normalize $tmp1

# convert back to RGB
if [ "$colormodel" = "HSL" -o "$colormodel" = "hsl" ]
	then	
	convert $tmp0 -colorspace HSL $tmpH -compose CopyRed -composite $tmpS -compose CopyGreen -composite $tmp1 -compose CopyBlue -composite -colorspace RGB $tmp1
fi

# color boost blend only if needed
if [ $fact -ne 0 ]
	then
	# create recolored image (normalize as log reduces range of values)
	if [ "$colormodel" = "HSL" -o "$colormodel" = "hsl" ]
		then	
		convert $tmp0 \( +clone -colorspace Gray \) -fx "log((u/max(v,.000001))+1)" $tmp2
	else
		convert $tmpA \( +clone -colorspace Gray \) -fx "log((u/max(v,.000001))+1)" $tmp2
	fi
	convert $tmp2 $tmp1 -compose multiply -composite -normalize $tmp3

	# blend recolored with unrecolored	
	composite -blend $fact% $tmp3 $tmp1 $tmp1

fi

if [ $bright -ne 100 -o $sat -ne 100 ]
	then
	modulate="-modulate ${bright},${sat}"
else
	modulate=""
fi

if [ `echo "$contrast != 1.0" | bc` -eq 1 ]
	then
	gamma="-gamma $contrast"
else
	gamma=""
fi

convert $tmp1 $gamma $modulate $outfile

exit 0
