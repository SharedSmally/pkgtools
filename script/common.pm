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
our @EXPORT = qw(trim  
     getNSDirStr getNSIncStr getNSPrefixStrs getNSSuffixStrs
     isTrue isFalse
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
	return uc($ns);	
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
