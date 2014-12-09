package Common;

use strict;
use warnings;
use Exporter;

our $DEBUG;

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( is_name is_dir is_help is_abs_path
    is_true is_false info debug warn error 
    trim ltrim rtrim trimRN trimText trimNewLine splitText onlySplitText align
    contains getUnique format_join
    writeFile writeArray readFile infoWriteFile
    $DENTS $SP1 $SP2 $CC_SEP $BACKUP
    getDirStr getFileSuffixStr getNS_underscore
);

# these are exported by default.
our @EXPORT = qw( info );

our $BACKUP=0;
our $MY_SEP=",";
our $DENTS=" "x3;
our $SP1=" "x3; our $SP2=${SP1}x2;
our $CC_SEP=",";
####################################################
# common-used subroutines
####################################################
sub is_name {
    my $str = shift;
    return $str =~ m/^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9_]$/;
}
sub is_dir {
    my $str = shift;
    return $str =~ m/^[\/a-zA-Z][a-zA-Z0-9_\/]*[a-zA-Z0-9_\/]$/;
}
sub is_help {
    my $str = shift;
    return ($str =~ /^-h$|^--h$|^-help$|^--help$/i);
}
sub is_abs_path {
    my $str = shift;
    return ($str =~ /^\//);
}
sub is_true {
    my $str = shift;
    return ($str =~ m/^t$/i) || ($str =~ m/^true$/i) || ($str =~ m/^yes$/i) ;
}
sub is_false {
    my $str = shift;
    return ($str =~ m/^f$/i) || ($str =~ m/^false$/i) || ($str =~ m/^false$/i) ;
}
####################################################

####################################################
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
####################################################
our $ALIGN_LEN=30;
sub align {
    my $str = $_[0]; my $len=$ALIGN_LEN;
    $len=$_[1] if $_[1];
    if (length($str) < $len) {
       $str .= " "x($len-length($str));
    }
    return $str;
}
####################################################
# Remove whitespace from the start and end of the string
sub trimRN  {
   my $string = shift; $string =~ s/^(\r|\n)+//;
   $string =~ s/(\s|\r|\n)+$//; return $string;
}
sub trimSRN  {
   my $string = shift; $string =~ s/^\s+(\r|\n)+$//;
   return $string;
}
sub trim {
    my $str = shift;
    $str =~ s/^\s+//; $str =~ s/\s+$//;
    return $str;
}
sub ltrim {
    my $str = shift;
    $str =~ s/^\s+//; 
    return $str;
}
sub rtrim {
    my $str = shift;
    $str =~ s/\s+$//;
    return $str;
}
# trim a string and replace SPACES* and ; with ,
sub trimText {
   my $s0=trim($_[0]);
   $s0 =~ s/\s+/${MY_SEP}/g; $s0 =~ s/";"+/${MY_SEP}/g; 
   $s0 =~ s/","+/${MY_SEP}/g;$s0 =~ s/${MY_SEP}+/${MY_SEP}/g;
   return $s0;
}
sub trimNewLine
{
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

####################################################
# Write a string to file: 
# arg1: filename
# arg2: string
sub infoWriteFile {  
  my $fname=$_[0]; my $s0=$_[1];
  
  info("create file ${fname}");
  if (!open (FILE, ">${fname}")) {
     print "error while opening file ${fname}\n"; return ;
  }; 
  print FILE ${s0}; close (FILE); 
}
sub writeFile {
  my $fname=$_[0]; my $s0=$_[1];
  if (!open (FILE, ">${fname}")) {
     print "error while opening file ${fname}\n"; return ;
  }; 
  print FILE ${s0}; close (FILE); 
}

# Write a string array to file: 
# arg1: filename
# arg2: string array
sub writeArray {
   writeFile($_[0], join("\n",@{$_[1]}));
}

sub readFile {
  local $/=undef;
  open FILE, $_[0] or die "Couldn't open file: $!";
  my $str = <FILE>;
  close FILE;
  return $str;

# or, if not able to unset $/ due to some other limitations in the script: 
# open FILE, $_[0] or die "Couldn't open file: $!"; 
#while (<FILE>){
# $string .= $_;
#}
#close FILE;
#
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
####################################################
# return directory string ending / if not empty
sub getDirStr {
   my $s0=trim($_[0]); $s0 =~ s/\s+//g;
   if (length($s0) > 0 ) {  unless ( $s0 =~ m/\/$/) { $s0 .= '/'; }  }
   return $s0;
}
# return file suffix string starting of . if not empty^M
sub getFileSuffixStr {
   my $s0=trim($_[0]); $s0 =~ s/\s+//g;
   if (length($s0) > 0 ) {  unless ( $s0 =~ m/^\./) { $s0 = ".${s0}"; } }
   return $s0;
}
# return namespace where :: is replaced by _
sub getNS_underscore {
   my $s0=trim($_[0]);
   $s0 =~ s/\s+/\_/g; $s0 =~ s/\/+/\_/g; $s0 =~ s/\:+/\_/g; $s0 =~ s/\.+/\_/g;
   if (length($s0) > 0 ) { unless ( $s0 =~ m/\_$/) { $s0 .= "_"; } }
   #print "ns_underscore: $s0\n";
   return $s0;
}
####################################################

####################################################
1
####################################################

