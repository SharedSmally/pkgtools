#!/usr/bin/perl -w

#
# commonly used subroutines
#
package common;
  
use strict;
use warnings;
use base 'Exporter';

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(
     trim padding paddingArray
     isTrue isFalse
     getNSDirStr getNSIncStr getNSPrefixStrs getNSSuffixStrs      
     toDir cmdDir lsArray normalizeNS
     arrayNormStr readArray writeArray
     );

########################################### const
#use constant { SEC   => 0,    MIN   => 1, };
#use constant PI    => 4 * atan2(1, 1);
# print "Pi equals ".PI."...\n";
#use constant ARRAY => [ 1,2,3,4 ];
#print ARRAY->[1];
#use constant WEEKDAYS => qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
#my @workdays = (WEEKDAYS)[1 .. 5];          # right
use constant SPACES => "   ";
use constant SEPERATOR => ",";
use constant DEFAULT_LEN => 20;
use constant DEFAULT_DELTA_LEN => 5;
#
#use common; #import all constants
#my $SP3=common::SPACES;
#
########################################### our vars
#our $OUR_SP1="sp1";
#our $OUR_SP2="sp2";
#@EXPORT = qw($OUR_SPACES); #optional
#
#use common;
#my $sp1=$OUR_SP1;
#my $sp2=common::$OUR_SP2;
#
our $OUR_SPACES="   ";
our $OUR_SP4="    ";

###########################################
#to lower case: lc
#to upper case:uc
#
sub ltrim {
	my $val=$_[0];	$val =~ s/^\s+//g;  
	return $val;
}
sub rtrim {
	my $val=$_[0];	$val =~ s/\s+$//g; 
	return $val;
}
sub trim {
	return ltrim(rtrim($_[0]));
}
sub padding {
	my $s0 = $_[0];
	my $suffix=(@_ >= 2) ? $_[1] : "";
	my $len =  ( @_ >= 3 ) ? $_[2] : DEFAULT_LEN ;
	my $mylen = $len - length($s0) - length($suffix);
	
	return "${s0}${suffix}" if ($mylen <= 0 );
	return $s0 . " " x ${mylen} . ${suffix};
}
###########
# padding with prefix(not for firs one) and suffix(not for last one)
sub paddingArray {
	my @a0=@{$_[0]};
	my $prefix=(@_ >= 2) ? $_[1] : "";
	my $suffix=(@_ >= 3) ? $_[2] : "";
	my $dlen = (@_ >= 4) ? $_[3] : DEFAULT_DELTA_LEN;
	
	my $maxlen = 0; my $d0=0;
	my $cnt=@a0; my $ind=1;
	foreach my $s0 (@a0) {
		$d0=length($s0);
		if ($ind==1) { $d0 += length($suffix); } 
		elsif ($ind==$cnt) { $d0 += length($prefix); }
		else {$d0 += length($prefix)+length($suffix); }
		$maxlen = $d0 if ($maxlen < $d0);
		++$ind; 
	}			
	
	my @array; $ind=1;
	foreach my $s0 (@a0) {
		if ($ind==1) {
			push(@array, padding($s0, $suffix, $maxlen));
		} elsif ($ind==$cnt) {
			push(@array, padding("${prefix}${s0}", "", $maxlen));
		} else {
			push(@array, padding("${prefix}${s0}", $suffix, $maxlen));	
		}		
		++$ind; 
	}	
	return \@array;
}

###############################
sub isTrue {
	my $v = trim($_[0]);
	return (  ($v =~ /^true$/i) || ($v =~ /^t$/i)
	       || ($v =~ /^yes$/i)  || ($v =~ /^y$/i) 
	       || ($v =~ /^\.t\.$/i) );  
}
sub isFalse {
	my $v = trim($_[0]);
	return (  ($v =~ /^false$/i) || ($v =~ /^f$/i)
	       || ($v =~ /^no$/i)  || ($v =~ /^n$/i) 
	       || ($v =~ /^\.f\.$/i) );  
}
#normalize string using seperator ,
sub arrayNormStr {
	my $s0 = trim($_[0]);
	my $sep=SEPERATOR;
	$s0 =~ s/\s+/${sep}/g; $s0 =~ s/\,+/${sep}/g; $s0 =~ s/:+/${sep}/g;
	return split($sep, $s0);
}
#############
# return strings from namespace A::B::C/A.B.C
# normalize namespace to A.B.C
sub normalizeNS {
	my $ns = trim($_[0]);
	$ns =~ s/\s+//g; $ns =~ s/\.+/\./g;$ns =~ s/:+/\./g;
	return $ns;
}
# return A/B/C for namespace
sub getNSDirStr {
	my $ns = normalizeNS($_[0]);
	$ns =~ s/\./\//g; 
	$ns .= "/" if ($ns);
	return $ns;	
}
# return A_B_C for namespace
sub getNSIncStr {
	my $ns = normalizeNS($_[0]);
	$ns =~ s/\./\_/g;
	return $ns; 
	#return uc($ns);	
}
sub getNSPrefixStrs {
	my @array;
	foreach my $val (split(/\./, $_[0])) {
		push(@array, "namespace ${val} {");
		#push(@array, "{");
	}	
	return \@array;
} 
sub getNSSuffixStrs {
	my @array;
	for (my $val=0; $val < $_[0]; $val++) {
		push(@array, "}");
	}	
	return \@array;	
}
######################
sub readArray {
	my $filename=$_[0];
	
	open(my $fh, "<$filename")  or die "Could not open file '${filename}' $!";
	my @array = <$fh>;  # Reads all lines into array
	#$singleLine = <$fh>;  # Reads just one line
	close ($fh);
	
	return \@array;
}
sub writeArray {
	my $filename=$_[0];
	my @array=@{$_[1]};
	print "save array to ${filename}\n";
	
	open(my $fh, ">$filename")  or die "Could not open file '${filename}' $!";
	print $fh join("\n",@array);	
	close ($fh);	
}
###########################################

################
sub toDir {	
	my $dir=$_[0];
	return "" if (length($dir)==0);
	$dir =~ s/^\s+//; $dir =~ s/\s+$//;
	$dir .= "/" unless ( $dir =~ /\/$/ );
	return $dir;
}
sub cmdDir {
	return toDir(`dirname $0`);
}

sub lsArray {
	my $pattern=$_[0];
	my $out = `ls ${pattern}`;
	$out =~ s/\s+/ /g;
	return split(" ", $out);
}
###########################################