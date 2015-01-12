#!/usr/bin/perl -w

#
# commonly used subroutines
#
package common;
  
use strict;
use warnings;
use base 'Exporter';
our $DEBUG=0;
#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(
     trim splitText
     padding paddingArray
     isTrue isFalse info isOlder
     getNSDirStr getNSIncStr getNSPrefixStrs getNSSuffixStrs
     contains getUnique format_join      
     toDir cmdDir lsArray normalizeNS
     arrayNormStr readArray writeArray   
     $DENTS $SP1 $SP2 $CC_SEP $BACKUP       
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

our $MY_SEP=",";
our $BACKUP=0;
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
our $OUR_SPACES="   "; our $OUR_SP4="    ";
our $CC_SEP=","; our $DENTS=" "x3;
our $SP1=" "x3;  our $SP2=${SP1}x2;
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
# trim a string and replace SPACES* and ; with ,
sub trimText {
   my $s0=trim($_[0]);
   $s0 =~ s/\s+/${MY_SEP}/g; $s0 =~ s/";"+/${MY_SEP}/g; 
   $s0 =~ s/","+/${MY_SEP}/g;$s0 =~ s/${MY_SEP}+/${MY_SEP}/g;
   return $s0;
}
sub trimNewLine{
   my $s0 = trimText($_[0]); #print "original: $s0\n";
   $s0 =~ s/\r/${MY_SEP}/g;  
   $s0 =~ s/\n/${MY_SEP}/g;  # print "replaced: $s0\n"; 
   return $s0; 
}
sub splitText { 
   return split(${MY_SEP}, trimText($_[0]));
}
sub onlySplitText {
   return split(${MY_SEP}, $_[0]);
}

###########################################################
######### padding string with max of length
#s1: string
#s2: prefix
#s3: suffix
#a4: length
#
# return s1{spaces}suffix
#
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
#s1: string array
#s2: prefix
#s3: suffix
#a4: length
#
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

####################################################
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

####################################################
# whether str is in container @a0;
sub contains {
    my $str = $_[0]; 
    foreach my $s0  (@{$_[1]}) {
       if ($str eq $s0) { return 1; }
    }
    return 0;
}
# return the unique element of an array
sub getUnique {
    my %seen = ();  my @r = ();
    foreach my $a (@{$_[0]}) {
        unless ($seen{$a}) {  push (@r, $a);   $seen{$a} = 1; }
    }
    return \@r;
}
####################################################

###############################################################
my $MAX_COL=80;
#
# join a list of strings into multi-row strings, max len for each row is MAX_COL  
# input: 
#   arg0: array of strings 
#   arg1: separator string  (opt)
#   arg2: prefix string for each row (opt)
#   arg3: string added for first row (opt)
#   arg4: string appended for last row (opt)
#   arg5: string appended for each (opt)
# return:
#   the formatted string
# 
sub format_join {  #@array; $sep, [$prefix; $firststr, $laststr]:
   return "" unless ($_[0]);
   my @as=@{$_[0]};
   my $sep=${CC_SEP}; $sep=$_[1] if ($_[1]);
   my $prefix="";  $prefix=$_[2] if ($_[2]);
   my $f0="";  $f0=$_[3] if ($_[3]);
   my $fn="";  $fn=$_[4] if ($_[4]);
   my $suf="";  $suf=$_[5] if ($_[5]);
   
   my $total_cnt=scalar(@as); 
   return "${f0}${fn}" if ($total_cnt==0);
   return "${f0}$as[0]${fn}" if ($total_cnt==1);
   
   #print "ta=", @{$_[0]}, "\n";   
   my (@ta, $x0, $x1);
   my $ss=length($sep);
   my $cnt=0; my $size=0; my $empty=1;
   
   foreach my $t0 (@{$_[0]}) {
     $cnt ++;  $empty=0; #$size0 = $size + length($t0) + $ss;
     if ($cnt==1) { #first one
        $x0 = "${f0}${t0}${sep}";
        if (length($x0)>$MAX_COL) {  push(@ta, $x0.${suf}); $x0="${prefix}"; $size=length($x0);
        } else {  $size=length($x0); }
     } elsif ($cnt == $total_cnt) {
        $t0 .= $fn; 
        if ($size + length($t0) > $MAX_COL) {
           push(@ta, $x0);  $x1 = "${prefix}${t0}"; push(@ta, $x1.${suf});
        } else {
           $x0 .= "$t0"; push(@ta, $x0.${suf}); 
        }
        $x0=""; $size=0;
     } else {
        $t0 .= $sep;
        if ($size + length($t0) > $MAX_COL) {
           push(@ta, $x0.${suf});  $x0 = "${prefix}${t0}"; $size=length($x0);
        } else {
           $x0 .= $t0; $size += length($t0);
        }     
     } 
   }

   #print "ta=", join(";",@ta), "\n"; #print "prefix=${prefix};\n";
   if ($empty) { return "${f0}${fn}" ; }
   else {   return join("\n", @ta); }
}
###############################################################
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
	return if (@array==0);
	print "save array to ${filename}\n";
	
	open(my $fh, ">$filename")  or die "Could not open file '${filename}' $!";
	print $fh join("\n",@array);	
	close ($fh);	
}
###########################################

################
sub info {
    print "  [INFO]:@_\n";
}
sub debug {
    if ($DEBUG) {  print "[DEBUG]:@_\n"; };
}
sub warn {
    print "  [WARN]:@_\n";
}
sub error {
   print "  [ERROR]:@_\n";;
}
##########################################

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
#
# return true if $f1 is older than $f2
sub isOlder {
	my ($f1,$f2)=@_;
    return  ((stat($f1))[9] < (stat($f2))[9]);		
}
###########################################