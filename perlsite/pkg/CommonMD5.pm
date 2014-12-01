package CommonMD5;

use strict;
use warnings;
use Exporter;

###############################################################
#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( parseLabelFile parseLabelFiles getMDLabels getLabelStr);

# these are exported by default.
our @EXPORT = qw( parseLabelFile );

###############################################################
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Common  qw(trim);
############################################################################
sub md {
  return uc(md5_hex($_[0]));
}
#
# input: string for MD5  
# return label strings (start$md5{s0}, end$md5{s0}, digest)
sub getMDLabels {
    my $digest = md($_[0]); 
    return ("// *CustomizedStart\@${digest}", "// *CustomizedEnd\@${digest}", $digest);
}
sub getLabelStrs {
    return ("// *CustomizedStart\@$_[0]", "// *CustomizedEnd\@$_[0]");
}

# input: str0 may contains MD start label string 
#return: MD5 label if exist or "" if not exist
sub getStartLabel{
    my $s0 = trim($_[0]);
    return $1 if ( $s0 =~ m/^\/\/ \*CustomizedStart\@(\w+)/i); 
    return "";
}

# input: str0 may contains MD end label string 
#return: MD5 label if exist or "" if not exist
sub getEndLabel{
    my $s0 = trim($_[0]);
    return $1 if ( $s0 =~ m/^\/\/ \*CustomizedEnd\@(\w+)/i);
    return "";
}

#input: file name that labelled using MD5 string
#return: map of {MD5} : customized code 
sub parseLabelFile {
  if (!open (FILE, "<$_[0]")) { print "error while opening file $_[0]\n"; return ; }; 
  
  my %labels; my @a1=();  my $flag=0; my $id="";  
  my $id0=""; my $t1; 
  foreach my $line ( <FILE> ){
    if ($flag == 0 ) {
       $id0 = getStartLabel($line);
       if (length($id0)>0) {
          $t1=join("", @a1);   #print "match $id; val=${t1}\n";
          if ( (length($id)>0) && (length($t1))>0) { $labels{$id}=$t1;} 
          $flag=1;  @a1=(); $id=$id0;
       }  
    } elsif ($flag == 1) {
       $id0 = getEndLabel($line);
       if ((length($id0)>0) && ($id0 eq $id) ) { $flag=0; }
       else { push(@a1, $line); }
    } 
  }
  close (FILE); $t1=join("", @a1);  #print "match $id; val=${t1}\n";
  if ( (length($id)>0) && (length($t1))>0) {$labels{$id}=$t1;}
    
  #showHash(\%labels);
  return \%labels;
}

sub parseLabelFiles {
    my (%codes, $x0);
    
    foreach my $t1 (@{$_[0]}) {
        next unless (-f $t1);
        $x0 = parseLabelFile($t1);  
        while ( my ($key, $val) = each %{$x0} ) {  $codes{$key}=$val; }
   }
   return \%codes; 
}
############################################################################
sub getLabelStr {
   my $ss=$_[0];  my %codes=%{$_[1]};
   my ($mds1, $mds2, $mds3)=getMDLabels($ss);
   $ss="\n"; $ss=$codes{$mds3} if (exists $codes{$mds3} ); 
   return "\n${mds1}\n${ss}${mds2}\n";
}
############################################################################
1
############################################################################