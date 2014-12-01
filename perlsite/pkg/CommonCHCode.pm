package CommonCHCode;

use strict;
use warnings;
use Exporter;

###############################################################
#define a module for unit test
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( saveHCode saveCCCode format_join );

# these are exported by default.
our @EXPORT = qw( saveHCode );

###############################################################
use Common qw(contains writeFile $CC_SEP);
###############################################################

###############################################################
#########  save the H source code in a file
# input:
#   arg0: home directory
#   arg1: filename(without suffix)
#   arg2: namespace
#   arg3: import_string
#   arg4: implement string array
#   arg5: bool, whether to backup the file is exists
#
# save output in header file:
#   #ifndefxxx
#   #definexxx
#   #himport****
#   namespace ns1{
#   namespace ns2{\n
#      @ha;
#   } 
#   }
#   #endif /*  end of xxx */
#
sub saveHCode {
   my $sep="/"x80;
   my $fname = $_[0]; # file name without .h
   my $ns=$_[1];      # namespace
   my $himp=$_[2];    # import string for h file.
   my $s1=join("\n", @{$_[3]});  $s1.="\n" if ($s1); # class contents
   my $bak=0;  $bak=$_[4] if ($_[4]);     # backup file.
   if ($_[5] && (scalar(@{$_[5]})>0)) { $s1.="\n${sep}\n"; $s1.=join("\n", @{$_[5]}); $s1 .="\n"; }
   my $hsuf=".h";  $hsuf=$_[6] if ($_[6]);    # file suffix.
   
   my $x0=toUnderscore ($fname); my $x1=$x0; my $x2=$himp;
   
   if ($ns) {
      my ($n1, $n2, $n3, $n4, $n5, $n6) = parseNS_Full($ns);
      $x1="${n3}$x0"; 
      
      if ($s1) { $x2 .= "\n" if ($x2); $x2 .="$n5\n\n${s1}\n$n6\n";} 
   } else {
      if ($s1) {  $x2 .= "\n" if ($x2); $x2.="${s1}"; }
   }

   my $s0="#ifndef ${x1}_h\n#define ${x1}_h\n\n${x2}\n#endif /* end of ${x1}_h */\n";
   $fname .= ${hsuf};    backFile($fname) if ( $bak && (-f $fname) ); 
   writeFile($fname, $s0);
}
#########  save the CC source code in a file
# input:
#   arg0: filename
#   arg1: namespace
#   arg2: import_string
#   arg3: implement string array
#   arg4: whether to backup file if exists
#
# save output in header file:
#   #cimport****
#   namespace ns1{
#   namespace ns2{
#      @ca;
#   }
#   } 
sub saveCCCode {
   my $fname = $_[0]; # file name without .cc
   my $ns=$_[1];      # namespace
   my $cimp=$_[2];    # import string for c file.
   my $bak=0;       $bak=$_[4] if ($_[4]);    # backup file.
   my $csuf=".cc";  $csuf=$_[5] if ($_[5]);   # file suffix.
   
   my $s1 = join("\n", @{$_[3]});
   
   # [ns1.ns2; ns1::ns2; ns1_ns2_; ns1/ns2/; namespace ns1{\nnamespace ns2 {; }\n}\n ]
   my ($n1, $n2, $n3, $n4, $n5, $n6) = parseNS_Full($ns);
   my $x0=toUnderscore ($fname);
   my $x2=""; $x2 = "${cimp}\n" if ($cimp); 

   my $s0="${x2}$n5\n\n${s1}\n$n6\n\n";
   $fname .= ${csuf};    backFile($fname) if ( $bak && (-f $fname) );  
   writeFile($fname, $s0);
}
###############################################################
###############################################################
# input: ns: a namespace string, seperator could be ., ::, /
# return (ns1.ns2; ns1::ns2; ns1_ns2_; ns1/ns2/; namespace{s1\nnamespace s2; }})
sub parseNS_Full {
   my $ns=$_[0];
   my ($t1, $t2, $t3, $x0, @a1, @a2);

   unless ($ns) { return ("", "", "", "", "", "");}

   $ns =~ s/\s+/\./g;   $ns =~ s/\:+/\./g; $ns =~ s/\/+/\./g;
   #print "CommonCHCode: ns=${ns}\n";
   foreach $t1 (split(/\./, ${ns})){
     $x0="namespace ${t1} {"; push(@a1, $x0);
     $x0="}"; push(@a2, $x0);
   }

   $t1=$ns;  $t1 =~ s/\./\:\:/g;
   $t2=$ns;  $t2 =~ s/\./\_/g;  if (length($t2)>1) {$t2 .= '_';}
   $t3=$ns;  $t3 =~ s/\./\//g;  if (length($t3)>1) {$t3 .= '/';}

   return ($ns, $t1, $t2, $t3, join("\n", @a1), join("\n", @a2));
}
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

############################################################### 
# replace //; . with _ 
sub toUnderscore {
   my $s0=$_[0];
   $s0 =~ s/\//\_/i; $s0 =~ s/\./\_/i; 
   return $s0;
} 
###############################################################
