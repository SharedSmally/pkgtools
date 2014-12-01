package CommonMember;

use strict;
use warnings;
use Exporter;

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( getVarAccessCodes getMemberDeclStr );

# these are exported by default.
our @EXPORT = qw( getVarAccessCodes );

use XML::LibXML;
use Common qw(trim trimRN);
use CommonXml qw( xml_true xml_false getXmlAttr);
use CommonType qw(isSimpleType isInteger);

###############################################################
our $SP1; our $CC_SEP; our $ACCSESS_NAME;
############################################################################
my $CLSNAME_INDEX=3;  # to access class name
# arg0: variable node
# return: (getMethodName, setMethodName)
my $VAR_ACCESS_NAME="visible";
my @VAR_ACCESS_PREFIX=("get","set");

sub getVarAccessMethodNames {
   my $node=$_[0];
   my $ac=""; $ac=$node->getAttribute($VAR_ACCESS_NAME) if ($node->hasAttribute($VAR_ACCESS_NAME));
   my $name=ucfirst($node->getAttribute("name"));
   my ($gs, $ss)=@VAR_ACCESS_PREFIX;
   $gs="is" if ( $node->hasAttribute("type") &&
                ( $node->getAttribute("type") =~ /^bool$/i ) );

   if (xml_false($node, "prefix")) {
      $name=$node->getAttribute("name");
      if      ( $ac =~ m/^read$/i )  {  return ("${name}","");  # read
      } elsif ( $ac =~ m/^readonly$/i )  {  return ("${name}","");  # const read only
      } elsif ( $ac =~ m/^accessonly$/i )  {  return ("${name}","");  # non-const read only
      } elsif ( $ac =~ m/^write$/i ) {  return ("","${name}");  # wrtite only
      } elsif ( $ac =~ m/^both$/i )  {  return ("${name}","${name}");# read/write
      } else  {  return ("",""); }
   } else {
      if      ( $ac =~ m/^read$/i )  {  return ("${gs}${name}","");  # read
      } elsif ( $ac =~ m/^readonly$/i )  {  return ("${gs}${name}","");  # const read only
      } elsif ( $ac =~ m/^accessonly$/i )  {  return ("${gs}${name}","");  # non-const read only
      } elsif ( $ac =~ m/^write$/i ) {  return ("","${ss}${name}");  # wrtite only
      } elsif ( $ac =~ m/^both$/i )  {  return ("${gs}${name}","${ss}${name}");# read/write
      } else  {  return ("",""); }
   }
}

############################################################################
# Input: Fields Decl string: ha & ca ()
#  arg0: fullname
#  arg1: node name
#  arg2: spaces
#
sub getMemberDeclStr {
    #my @fullname = @{$_[0]}; # name info for class
    my $name=$_[1]->nodeName;
    return getConstDecl($_[0],$_[1],$_[2]) if ($name eq "const");
    return getVarDecl($_[0],$_[1],$_[2]) if ($name eq "var");
    return getVarDecl($_[0],$_[1],$_[2]) if ($name eq "variable");
    return getConfigDecl($_[0],$_[1],$_[2]) if ($name eq "config");
    return getCountDecl($_[0],$_[1],$_[2]) if ($name eq "count");
    return getProfileDecl($_[0],$_[1],$_[2]) if ($name eq "profile");
    return getProfileDecl($_[0],$_[1],$_[2]) if ($name eq "metric");
}
sub getVarAccessCodes {
    #my @fullname = @{$_[0]}; # name info for class
    my $name=$_[1]->nodeName;
    return getConstAccessStr($_[0],$_[1],$_[2]) if ($name eq "const");
    return getVarAccessStr($_[0],$_[1],$_[2]) if ($name eq "var");
    return getVarAccessStr($_[0],$_[1],$_[2]) if ($name eq "variable");    
    return getConfigAccessStr($_[0],$_[1],$_[2]) if ($name eq "config");
    return getCountAccessStr($_[0],$_[1],$_[2]) if ($name eq "count");
    return getProfileAccessStr($_[0],$_[1],$_[2]) if ($name eq "profile");
    return getProfileAccessStr($_[0],$_[1],$_[2]) if ($name eq "metric");
}

sub getConstDecl {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);

    my $clsname=$fullname[2];

    my $t0 = $node->getAttribute("type");
    if (xml_true($node,"ref")) {  $t0 .= " & "; };

    my $n0 = $node->getAttribute("name");
    $n0 = getXmlAttr($node,"realname",$n0);
    my $x0 = "${clsname}::$n0 = ";
    my $v0 = getXmlAttr($node, "value","");
	$v0 = getXmlAttr($node, "default",$v0);

    if (length($v0)>0) {
       if (xml_true($node,"string")) {  $v0="\"$v0\"" ; }
       else { if (xml_true($node,"char")) {   $v0="\'$v0\'";  } }
    } else {  # get <value></value>
       my @vals; my $v1;
       my $sep; my $sep1;
       if (xml_true($node,"string")) { $sep = "\", \""; $sep1 = "\"";}
       else {
          if (xml_true($node,"char")){ $sep="\', \'"; $sep1 = "\'";}
          else { $sep=", ";  $sep1 = ""; }
       }
    }
    if ($node->textContent) { $v0 .= trimRN($node->textContent); }

    my $pt0="";
    $pt0="${clsname}::"if (xml_true($node,"self"));
    
    if ($node->hasAttribute("array")) {
         my $a0=$node->getAttribute("array");
         my $s0="${sp}static const $t0 $n0\[$a0\] ;";
         my $s2=""; $s2="$fullname[1]\n" if ($fullname[1]);
         my $s1="${s2}const ${pt0}$t0 ${clsname}::$n0\[$a0\] = {\n$v0\n};\n";
         return ($s0,$s1);
    } else {
         my $s0="${sp}static const $t0 $n0 ;";
         my $s2=""; $s2="$fullname[1]\n" if ($fullname[1]);
         my $s1="${s2}const ${pt0}$t0 ${clsname}::$n0 = $v0 ;";
         return ($s0,$s1);
    }
}
#
# return ({[const] [static] type name}, {[const] [static] type $clsname::name}, simpleType }
sub getMemberPrefix {
    my $node=$_[0];
    my $sp="";  $sp=$_[1] if ($_[1]);

   my $psa=$sp; $psa .= "static " if (xml_true($node,"static"));
   $psa .= "const " if (xml_true($node,"const")) ;

   my $psc="";
   $psc .= "const " if (xml_true($node,"const")) ;

   my $ref=" ";  $ref = " & " if (xml_true($node,"ref")) ;

   return ($psa, $psc, $ref);
}
sub getVarDecl {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp=${SP1};  $sp=$_[2] if ($_[2]);

    my ($sap, $scp, $ref)= getMemberPrefix ($_[1], $sp);

    my $t0 = $node->getAttribute("type");
    my $n0;
    if ($node->hasAttribute("realname")) {  $n0 = $node->getAttribute("realname");}
    else { $n0 = $node->getAttribute("name"); }

    if ($node->hasAttribute("array")) {
       my $t1=$node->getAttribute("array");
       $n0 .= "[${t1}" unless ($t1 =~ m/^\[/);
       $n0 .= "]" unless ($t1 =~ m/\]/);
    }
    my $sa="$sap$t0$ref$n0";

    my $x0=getXmlAttr($node,"value","");
    $x0=getXmlAttr($node,"default","") if (length($x0)==0);
    $x0= "\"$x0\"" if (xml_true($node,"string"));

    my $hasval=$node->hasAttribute("value") || $node->hasAttribute("default");

    if (!xml_true($node,"static")) {if (!xml_true($node,"const")) {$hasval=0;}}

    if (isInteger($t0) || xml_true($node,"inline") ) { #integer
       if ($hasval) {   return ("$sa = $x0;", "") ;
       } else {   return ($sa.";", "") }
    }

    my $clsname=$fullname[3]; my $sc="";
    
    my $pt0="";
    $pt0=" ${clsname}::"if (xml_true($node,"self"));
        
    if ($hasval) {  
    	if ($x0 =~ m/^none$/i ) {
    		$sc="${scp}${pt0}${t0}${ref}${clsname}::$n0;"; 
    	} else {    		
    		$sc="${scp}${pt0}${t0}${ref}${clsname}::$n0 ($x0);";
    	}
    }
    #else { $sc="$scp$t0${ref}${clsname}::$n0;";}

    return ($sa.";", $sc );
}
sub getConfigInitStr {
   my $node=$_[0];
   my @ca;

   return join(",", @ca);
}
sub getConfigDecl {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);

    my ($sap, $scp, $ref)= getMemberPrefix ($_[1], $sp);

    my $t0 = $node->getAttribute("type");
    my $c0 = "Config";  $c0=$node->getAttribute("category") if ($node->hasAttribute("category") );
    $t0="$c0<$t0>";  # Config/Configs/ConfigSet/ConfigMap<type>

    my $n0 = $node->getAttribute("realname");

    my $sa="$sap${t0}${ref}$n0;";

    return return ( $sa, "") unless (xml_true($node,"static")) ;

    my $clsname=$fullname[3];
    my $ca = "$scp${t0}${ref}$n0 $clsname::"; $ca .= getConfigInitStr($node);
    return ($sa, $ca);
}
sub getCountInitStr {
   my $node=$_[0];
   my @ca;

   return join(",", @ca);
}
sub getCountDecl {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);

    my ($sap, $scp, $ref)= getMemberPrefix ($_[1], $sp);

    my $t0 =""; $t0 = $node->getAttribute("size") if ($node->hasAttribute("size"));
    $t0="Counter${t0}";
    my $n0 = $node->getAttribute("realname");

    my $sa="$sap${t0}${ref}$n0;";

    return return ( $sa, "") unless (xml_true($node,"static")) ;

    my $clsname=$fullname[3];
    my $ca = "$scp${t0}${ref}$n0 $clsname::"; $ca .= getCountInitStr($node);
    return ($sa, $ca);
}
sub getProfileInit {
   my $node=$_[0];
   my @ca;

   return join(",", @ca);
}
sub getProfileDecl {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);

    my ($sap, $scp, $ref)= getMemberPrefix ($_[1], $sp);

    my $t0 = ""; $t0=$node->getAttribute("size") if ($node->hasAttribute("size"));
    $t0="Profile< ${t0} >";

    my $n0 = $node->getAttribute("realname");

    my $sa="$sap${t0}${ref}$n0;";

    return return ( $sa, "") unless (xml_true($node,"static")) ;

    my $clsname=$fullname[3];
    my $ca = "$scp${t0}${ref}$n0 $clsname::"; $ca .= getProfileInitStr($node);
    return ($sa, $ca);
}
############################################################################

############################################################################
# (static_protected; static_privated; class_protected; class_privated)
############################################################################
sub getConstAccessStr {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);
    my $clsname=$fullname[3];
    my $fclsname=$fullname[2];

    my ($gname, $sname)= getVarAccessMethodNames($node);
    my (@ha, @ca, @hm);

    my $t0 = $node->getAttribute("type");
    my $t1=isSimpleType($t0); $t0 .= " ";

    my $st="static const ";
    my $name = $node->getAttribute("name");
    my $fname = $node->getAttribute("realname");
    my $ref=""; $ref="& " unless ($t1);
    $ref="" if (xml_false($node,"ref"));
    my $x1;
    if ($gname) { # get method; only read
       if (xml_false($node,"inline")) {  # force not using inline
          $x1="${sp}static const ${t0}${ref}$gname(); ";  push(@ha,$x1);
          $x1="}$gname(); ";  push(@hm,$x1);
          $x1="const ${t0}${ref}${fclsname}::$gname() {\n   return $fname; \n};"; push(@ca,$x1);
       } else {  #inline; [const] type & getXXX() [const]
          $x1="${sp}static const ${t0}${ref}$gname() { return $fname; }; ";  push(@ha,$x1);
       }
    }
    return (\@ha, \@ca, \@hm);
}
sub getVarAccessStr {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);
    my $clsname=$fullname[3];
    my $fclsname=$fullname[2];

    my ($gname, $sname)= getVarAccessMethodNames($node);
    my (@ha, @ca, @hm);

    my $t0 = trim($node->getAttribute("type"));
    my $t1=isSimpleType($t0);  if (not $t1) { $t1=1 if ($t0 =~ m/\*$/); }
    $t0 .= " ";
    my $access=getXmlAttr($node,$VAR_ACCESS_NAME,"");
    my $readconst = 0; my $readvar = 0;
    if ($access =~ m/^readonly$/i) { $readconst=1; $readvar=0; }
    elsif ($access =~ m/^accessonly$/i) { $readconst=0; $readvar=1; }
    elsif ($access =~ m/^read$/i) { $readconst=1; $readvar=1; }
    elsif ($access =~ m/^both$/i) { $readconst=1; $readvar=1; }

    my $st=""; $st="static " if (xml_true($node,"static"));
    my $name = $node->getAttribute("name");
    my $fname = $node->getAttribute("realname");
    my $cst=""; $cst="const " unless (xml_true($node,"static"));
    my $cst0=""; $cst0="const " unless (xml_true($node,"static") || $t1);
    if (xml_false($node,"const")) {$cst0=""; $cst="";};
    my $ref=""; $ref="& " unless ($t1);
    $ref="" if (xml_false($node,"ref"));

    my $x1;

    if ($t1) { $readconst=1; $readvar=0; };  #simple type; only xxx getxxx() const;
    if (xml_true($node, "static")) {$readconst=0; $readvar=1;} ; #static; only xxx getxxx()

    if ($gname) { # get method
       if (xml_false($node,"inline")) {  # force not using inline
          if ($readconst) {
             $x1="${sp}${st}${cst0}${t0}${ref}$gname() ${cst}; ";  push(@ha,$x1);
             $x1="}$gname()${cst}; ";  push(@hm,$x1);
             $x1="${st}${cst0}${t0}${ref}${fclsname}::$gname() ${cst} {\n   return $fname; \n};"; push(@ca,$x1);
          }
          if ( $readvar ){ # non_static
             $x1="${sp}${t0}${ref}$gname(); ";  push(@ha,$x1);
             $x1="$gname(); ";  push(@hm,$x1);
             $x1="${t0}${ref}${fclsname}::$gname() {\n   return $fname; \n};"; push(@ca,$x1);
          }
       } else {  #inline; [const] type & getXXX() [const]
          if ($readconst) {
            $x1="${sp}${st}${cst0}${t0}${ref}$gname() ${cst} { return $fname; }; ";  push(@ha,$x1);
            $x1="$gname()${cst}";  push(@hm,$x1);
          }
          if ( $readvar) {
            $x1="${sp}${t0}${ref}$gname() { return $fname; }; ";  push(@ha,$x1);
            $x1="$gname(); ";  push(@hm,$x1);
          }
       }
    }
    if ($sname) {  # set method
       if (xml_false($node,"inline")) {  # force not using inline
          $x1="${sp}${st}void $sname(${cst}${t0}${ref} val); ";  push(@ha,$x1);
          $x1="$sname(${cst}${t0}${ref}) ";  push(@hm,$x1);
          $x1="${st}void $sname(${cst}${t0}${ref} val) {\n   $fname=val; \n};"; push(@ca,$x1);
       } else {  #inline; [const] type & getXXX() [const]
          $x1="${sp}${st}void $sname(${cst}${t0}${ref} val) { $fname=val; }; ";  push(@ha,$x1);
          $x1="$sname(${cst}${t0}${ref}) ";  push(@hm,$x1);
       }
    }
    #print "commonMember:: @ha;\n; @ca;\n;@hm;\n";
    return (\@ha, \@ca, \@hm);
}
sub getConfigAccessStr {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);
    my $clsname=$fullname[3];
    my $fclsname=$fullname[2];

    my ($gname, $sname)= getVarAccessMethodNames($node);
    my (@ha, @ca, @hm);

    my $t0 = $node->getAttribute("type"); $t0 .= " ";
    my $t1=isSimpleType($t0);

    my $st=""; $st="static " if (xml_true($node,"static"));
    my $name = $node->getAttribute("name");
    my $fname = $node->getAttribute("fname");
    my $cst=""; $cst="const " unless (xml_true($node,"static"));
    my $ref=""; $ref="& " unless ($t1);
    my $x1;

    if ($gname) { # get method
       if (xml_false($node,"inline")) {  # force not using inline
          $x1="${sp}${st}${cst}${t0}${ref}$gname() ${cst}; ";  push(@ha,$x1);
          $x1="}$gname()${cst}; ";  push(@hm,$x1);
          $x1="${st}${cst}${t0}${ref}${fclsname}::$gname() ${cst} {\n   return $fname.vallue(); \n};"; push(@ca,$x1);

          if ( !($t1) && !(xml_true($node, "static") ) ){ # non_static
             $x1="${sp}${t0}${ref}$gname(); ";  push(@ha,$x1);
             $x1="$gname(); ";  push(@hm,$x1);
             $x1="${t0}${ref}${fclsname}::$gname() {\n   return $fname.value(); \n};"; push(@ca,$x1);
          }
       } else {  #inline; [const] type & getXXX() [const]
          $x1="${sp}${st}${cst}${t0}${ref}$gname() ${cst} { return $fname.value(); }; ";  push(@ha,$x1);
          $x1="$gname()${cst}";  push(@hm,$x1);

          if ( !($t1) && !(xml_true($node, "static") ) ){
            $x1="${sp}${t0}${ref}$gname() { return $fname.value(); }; ";  push(@ha,$x1);
            $x1="$gname(); ";  push(@hm,$x1);
          }
       }
    }
    if ($sname) {  # set method
       if (xml_false($node,"inline")) {  # force not using inline
          $x1="${sp}${st}void $sname(${cst}${t0}${ref} val); ";  push(@ha,$x1);
          $x1="$sname(${cst}${t0}${ref}) ";  push(@hm,$x1);
          $x1="${st}void $sname(${cst}${t0}${ref} val) {\n   $fname=val; \n};"; push(@ca,$x1);
       } else {  #inline; [const] type & getXXX() [const]
          $x1="${sp}${st}void $sname(${cst}${t0}${ref} val) { $fname=val; }; ";  push(@ha,$x1);
          $x1="$sname(${cst}${t0}${ref}) ";  push(@hm,$x1);
       }
    }

    return (\@ha, \@ca, \@hm);
}
sub getCountAccessStr {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);
    my $clsname=$fullname[3];
    my $fclsname=$fullname[2];

    my (@ha, @ca, @hm);

    my $t0 = "uint";
    if ($node->hasAttribute("size")) { $t0 .= $node->getAttribute("size") ; $t0 .= " ";}

    my $st=""; $st="static " if (xml_true($node,"static"));
    my $name = $node->getAttribute("name");  $name=cap($name);
    my $fname = $node->getAttribute("fname");
    my $cst=""; $cst="const " unless (xml_true($node,"static"));
    #my $ref=""; $ref="& " unless ($t1);
    my $gname=$VAR_ACCESS_PREFIX[0]; $gname .= uc($name);
    my $x1;

    if (xml_false($node,"inline")) {  # force not using inline
       $x1="${sp}${st}${cst}${t0}$gname() ${cst}; ";  push(@ha,$x1);
       $x1="$gname()${cst}; ";  push(@hm,$x1);
       $x1="${st}${cst}${t0}${fclsname}::$gname() ${cst} {\n   return $fname.vallue(); \n};"; push(@ca,$x1);

       $gname="inc${name}"; #inc
       $x1="${sp}${st}void $gname(); ";  push(@ha,$x1);
       $x1="$gname(); ";  push(@hm,$x1);
       $x1="${st}void ${fclsname}::$gname(){\n   ++$fname; \n};"; push(@ca,$x1);

       if ( xml_true($node, "dec") ) { # dec
          $gname="dec${name}"; #inc
          $x1="${sp}${st}void $gname(); ";  push(@ha,$x1);
          $x1="$gname(); ";  push(@hm,$x1);
          $x1="${st}void ${fclsname}::$gname(){\n   --$fname; \n};"; push(@ca,$x1);
       }
       if ( xml_true($node, "reset") ) { # reset
          $gname="reset${name}"; #inc
          $x1="${sp}${st}void $gname($t0 v = 0); ";  push(@ha,$x1);
          $x1="$gname($t0); ";  push(@hm,$x1);
          $x1="${st}void ${fclsname}::$gname($t0 v){\n   $fname.reset(v); \n};"; push(@ca,$x1);
       }
    } else {  #inline; [const] type & getXXX() [const]
       $x1="${sp}${st}${cst}${t0}$gname() ${cst} { return $fname.value(); }; ";  push(@ha,$x1);
       $x1="$gname()${cst}; ";  push(@hm,$x1);

       $gname="inc${name}"; #inc
       $x1="${sp}${st}void $gname() { ++$fname; }; ";  push(@ha,$x1);
       $x1="$gname(); ";  push(@hm,$x1);

       if ( xml_true($node, "dec") ) { # dec
          $gname="dec${name}"; #inc
          $x1="${sp}${st}void $gname() { --$fname; }; ";  push(@ha,$x1);
          $x1="$gname(); ";  push(@hm,$x1);
       }
       if ( xml_true($node, "reset") ) { # reset
          $gname="reset${name}"; #inc
          $x1="${sp}${st}void $gname($t0 v = 0) { $fname.reset(v); }; ";  push(@ha,$x1);
          $x1="$gname($t0); ";  push(@hm,$x1);
       }
    }

    return (\@ha, \@ca, \@hm);
}
sub getProfileAccessStr {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1];
    my $sp="";  $sp=$_[2] if ($_[2]);
    my $clsname=$fullname[3];
    my $fclsname=$fullname[2];

    my (@ha, @ca, @hm);

    my $t0 = $node->getAttribute("type"); $t0 .= " ";  #not simpleType

    my $st=""; $st="static " if (xml_true($node,"static"));
    my $name = $node->getAttribute("name"); $name=cap($name);
    my $fname = $node->getAttribute("fname");
    my $cst=""; $cst="const " unless (xml_true($node,"static"));
    my $ref="& ";
    my $x1;

    my $gname=$VAR_ACCESS_PREFIX[0]; $gname .= uc($name);
    if (xml_false($node,"inline")) {  # force not using inline
      $x1="${sp}${st}${cst}${t0}${ref}$gname() ${cst}; ";  push(@ha,$x1);
      $x1="}$gname()${cst}; ";  push(@hm,$x1);
      $x1="${st}${cst}${t0}${ref}${fclsname}::$gname() ${cst} {\n   return $fname; \n};"; push(@ca,$x1);

      unless ( xml_true($node, "static") ){ # non_static
         $x1="${sp}${t0}${ref}$gname(); ";  push(@ha,$x1);
         $x1="$gname(); ";  push(@hm,$x1);
         $x1="${t0}${ref}${fclsname}::$gname() {\n   return $fname; \n};"; push(@ca,$x1);
      }

      if (xml_true($node, "reset")) {
         $gname="reset${name}";
         $x1="${sp}${st}${t0}${ref}$gname(); ";  push(@ha,$x1);
         $x1="$gname(); ";  push(@hm,$x1);
         $x1="${st}${t0}${ref}${fclsname}::$gname() {\n   return $fname.reset(); \n};"; push(@ca,$x1);
      }
    } else {  #inline; [const] type & getXXX() [const]
      $x1="${sp}${st}${cst}${t0}${ref}$gname() ${cst} { return $fname; } ; ";  push(@ha,$x1);
      $x1="}$gname()${cst}; ";  push(@hm,$x1);

      unless ( xml_true($node, "static") ){ # non_static
         $x1="${sp}${t0}${ref}$gname() { return $fname; }; ";  push(@ha,$x1);
         $x1="$gname(); ";  push(@hm,$x1);
      }

      if (xml_true($node, "reset")) {
         $gname="reset${name}";
         $x1="${sp}${st}${t0}${ref}$gname() { $fname.reset(); } ";  push(@ha,$x1);
         $x1="$gname(); ";  push(@hm,$x1);
      }
    }
    return (\@ha, \@ca, \@hm);
}
############################################################################
1
############################################################################