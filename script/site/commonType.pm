#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonType;
  
use strict;
use warnings;
use base 'Exporter';
#use Exporter;

use XML::LibXML;

use common qw( trim splitText contains format_join is_true);
use commonXml qw( xmlRoot getXmlAttr isXmlTrue isXmlFalse);

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( 
     isInteger isSimpleType 
     getTypeStr getReturnStr 
     getArgStrs getArgsStrings 
     getTemplateTypeStrs
     isInline isRealInline isVirtual
     getImplStrings 
   );

# these are exported by default.
our @EXPORT = qw( getTypeStr );
###########################################################################
# input: type string
# return: true if type string is one of predefined simple types
###############################################################
sub isInteger {
   my @IntegerTypes=(
      "bool",  "boolean",
      "char",  "unsigned char",  "signed char",   "int8",  "uint8",  "int8_t",  "uint8_t",
      "short", "unsigned short", "signed short",  "int16", "uint16", "int16_t", "uint16_t",
      "int",   "unsigned int",   "signed int",    "int32", "uint32", "int32_t", "uint32_t",
      "long",  "unsigned long",  "signed long",   "int64", "uint64", "int64_t", "uint64_t",
      "long long", "unsigned long long", "signed long long",   "size_t", "ssize_t", "off_t"
   );
   return contains($_[0],\@IntegerTypes);
}

sub isSimpleType { #integer and real numer; other POD structs
   my @RealTypes=( "double", "float");
   return 1 if (isInteger($_[0]));
   return contains($_[0],\@RealTypes);
}
###############################################################
###########################################################################
my $CC_SEP=", ";
my $SP1=" "x3;
############################################################################
# return type string for type-node: prefix for internal class/types
#  <xxx type|class="" template="" typedef="" typename="true|false" prefix="">
#      <template>*   # list-of-type node as template
#  </xxx>
############################################################################
sub getTypeStr {
  my $node=$_[0];

  # for ${typename} ${prefix}${class}<templates>::typedef  
  my $cls=getXmlAttr($node,"type","");
  $cls=getXmlAttr($node,"class","") unless ($cls);
  
  $cls="typename ${cls}" if (isXmlTrue($node, "typename"));

  my @tmp;
  my $t1=getXmlAttr($node,"template","");  push(@tmp,$t1) if ($t1);

  foreach $t1 ($node->getChildrenByTagName("template")) {
     push(@tmp, getTypeStr($t1));
  }
  $t1=join(",",@tmp); $cls="$cls < $t1 >" if ($t1);
  
  $t1=getXmlAttr($node,"typedef","");
  $cls .= "::${t1}" if ($t1);
  
  $t1=getXmlAttr($node,"prefix","");
  $cls = "${t1}${cls}" if ($t1);

  return $cls;
}
############################################################################

############################################################################^M
# get the string for method/function return type
# <xxx return="xxx|none" ref="true|false">
#    <return ref="true|false" const="true|false" type="" > : simple type 
# or
#    <return ref="true|false" const="true|false"
#       class="" template="" typedef="" typename="true|false">
#       <template>*   # list-of-type node
#    </return>
# </xxx>
# empty for constructor/deconstructor 
sub getReturnStr {
   my $node=$_[0];
   
   my $ret=trim(getXmlAttr($node,"return",""));
      
   return "" if ($ret =~ m/^none$/i);
      
   unless ($ret) {
      foreach my $t1 ($node->getChildrenByTagName("return")) { 
         $ret = getArgTypeStr($t1); 
      }   
   }
   
   return "void " unless ($ret);   
   
   $ret .= " & " if (isXmlTrue($node,"ref"));
   return $ret; 
}
############################################################################
############################################################################
# get the string for method/function arg type
# <xxx args="int arg1,bool arg2">
#    <arg name="" ref="true|false" const="true|false" type="" default=""> : simple type 
#    <arg ref="true|false" const="true|false" default=""
#       class="" template="" typedef="" typename="true|false">
#       <template>*   # list-of-type node
#    </arg>
# </xxx>
#
sub getArgsStrings {
    my $node=$_[0];
    my (@ha,@ca,@sa);
    my ($f0, $fn, $fi);
    
   if ($node->hasAttribute("args") || $node->hasAttribute("arg") ) {
       $f0= getXmlAttr($node,"args","");
       $f0= getXmlAttr($node,"arg","") unless ($f0);
       push(@ha, $f0);push(@ca, $f0);
       foreach my $t1 (split(",", $f0) ) {
          my @a0=split(" ", $t1);
          if (scalar(@a0)>1) {  pop(@a0); push(@sa, join(" ", @a0));
          } else {push(@sa, $t1);}
       }
   }
   foreach my $t1 ($node->getChildrenByTagName("arg")) {
      ($f0, $fn, $fi) = getArgStrs($t1); 
       push(@ha, $f0);push(@ca, $fn); push(@sa, $fi);
   }
   return (\@ha,\@ca,\@sa);
}

#################################################
# return 3 type strings:
#    type name [=default],
#    type name,
#    type,
sub getArgStrs {
  my $node=$_[0];
   
  my $name=getXmlAttr($node,"name","");
  my $type=getArgTypeStr($node);
   
  my $df=getXmlAttr($node, "default","");   
  $df="\"$df\"" if (isXmlTrue($node, "string") && ($df || $node->hasAttribute("default")) );
  $df ="=$df" if ( length($df) > 0);
  
  return ("$type ${name}${df}", "$type ${name}", "$type");  
}
#################################################
# a type with array, ref, const attribute
sub getArgTypeStr {
   my $node=$_[0];
   
   my $ret= trim(getTypeStr($node));
   return $ret unless ($ret);
   
   if ($node->hasAttribute("array")) { 
      my $t0=$node->getAttribute("array"); $ret="$ret [$t0]";
   };

   my $t1=not(isXmlFalse($node,"ref"));
   
   if (isSimpleType($ret) || ($ret =~ m/\&$/) || ($ret =~ m/\*$/) ) { 
      $ret .= " & " if (isXmlTrue($node,"ref")); #ref if explicitly true
   } else { $ret .= " & " if (not isXmlFalse($node,"ref")); } # ref if not explicit false 
   
   $ret = "const $ret" if (isXmlTrue($node,"const"));

   return $ret;
}
############################################################################
# generate typename strings for typename node: [type.xsd::TemplateType]
# <template [typename="(typename)"] name="" [start="(1)"] [size="(1)"] suffix="" 
#      [default="val"] >
#     <default/>   #type node
# </template>
#
#return typename strings: (s1,s2,s3)
# s1: typename T1, ..., typename Tn=default
# s2: typename T1, ..., typename Tn
# s3: T1, ..., Tn
############################################################################
sub getTemplateStrs {
  my $node=$_[0];
  
  my $name=trim($node->getAttribute("name"));
  my $tname = getXmlAttr($node,"typename", "typename");
  my $start=getXmlAttr($node,"start", 1);
  my $suffix=getXmlAttr($node,"suffix", "");
  my $size=0;  $size=int($node->getAttribute("size")) if ($node->hasAttribute("size"));
  
  my $flag=$node->hasAttribute("default");
  my $val=getXmlAttr($node,"default","");
  foreach my $t1 ($node->getChildrenByTagName("default") ) {
      $val = getTypeStr($t1); $flag=1;
  }
  $val = " = $val" if ($flag);
  
  my $st; my (@sta, @sca, @suf); my $ind;
  if ($size==0) {  # typename name
     push(@suf, $name);
     $st="$tname $name$val"; push(@sta, $st);  
     $st="$tname $name"; push(@sca, $st);
  } else {   #typename name1, ..., typename namen
     for (my $cnt=0; $cnt<$size; ++$cnt) {
        $ind=$start+$cnt;
        $st="${name}${ind}${suffix}";  push(@suf, $st);
        $st="$tname ${name}${ind}${suffix}${val}"; push(@sta, $st);
        $st="$tname ${name}${ind}${suffix}"; push(@sca, $st);
     } 
  }
  return (join(${CC_SEP}, @sta), join(${CC_SEP}, @sca), join(${CC_SEP}, @suf));
}
############################################################################

############################################################################
# generate template strings for templates node: [type.xsd::FullTemplateType]
# <xxx typename="" template="T1,T2" templatetype="int,10,bool">
#   <template name="" [typename="(typename)"] [start="(1)"] [size="(1)"] 
#        [default="type"] >   #type node
#       <default/>    # type node
#   </template>*      # template node
#   <templatetype type="" [class="" template="" typedef="">   #type node
#       <template/> #template type node
#   </templatetype>*  # type node
# </xxx>
#
#return template strings: (s1,s2,s3, s4,s5,s6)
# s1: template <typename T1, ..., typename Tn=default>
# s2: template <typename T1, ..., typename Tn>
# s3: <T1, ..., Tn> # real templates; template
# s4: <P1,..., Pm>  # partial parameterized: templatetype
# s5: <T1,...,Tn,P1,...,Pm>
# s6: number of real templates: n
############################################################################
sub getTemplateTypeStrs {
  my $node = $_[0];
  my $sp="${SP1}";  $sp = $_[1] if ($_[1]);
  
  my (@ta, @ca, @suf, @fullsuf, $x0, $x1, $x2, $x3);
  
  # for partial/full specialized template classes: 
  # template<templates> class<templates, templatetypes>::yyy()
  my @pa;  
  if ($node->hasAttribute("template") ) {
     $x0=$node->getAttribute("template");
     my $t0=getXmlAttr($node,"typename","typename");
     foreach $x1 (split(",",$x0)) {     	 
         my @t1=split("=",trim($x1));
         if (scalar(@t1)==1) {
            $x2=trim($t1[0]); push(@suf, $x2); 
            push(@fullsuf, $x2);
            $x2="${t0} $x2"; push(@ta, $x2); push(@ca, $x2);
         } elsif (scalar(@t1)==2) {
            $x2=trim($t1[0]); push(@suf, $x2);
            $x2="${t0} $x2"; push(@ca, $x2); 
            $x3=trim($t1[1]); $x2="${t0} $x2=$x3";push(@ta, $x2);
         }
     }
  }
  ##### partial="&" or "*" for case:
  # template <typename T>
  # class TypeTraits<T *>
  #
  foreach my $t1 ($node->getChildrenByTagName("template") ) {
     ($x1, $x2, $x3) = getTemplateStrs($t1);       
     push(@ta, $x1); push(@ca, $x2);  
     
     if ($t1->hasAttribute("partial")) { 
     	my $p=$t1->getAttribute("partial"); $x3 .= " $p ";
     	push(@suf, $x3); push(@fullsuf, $x3);
     	push(@pa, $x3);
     } else { 
     	push(@suf, $x3); push(@fullsuf, $x3);
     }
  }  

  ############################### 
  #partial parameters
  my $tpflag=0;
  if ($node->hasAttribute("templatetype")) {
     $x1=$node->getAttribute("templatetype");
     push(@pa,$x1); push(@fullsuf,$x1); $tpflag=1;
  } elsif ($node->hasAttribute("templatetypes")) {
     $x1=$node->getAttribute("templatetypes");
     push(@pa,$x1); push(@fullsuf,$x1); $tpflag=1;
  }
  
  foreach my $t1 ($node->getChildrenByTagName("templatetype") ) {
     $x1=getTypeStr($t1);  $tpflag=1; 
     push(@pa,$x1); push(@fullsuf,$x1);
  }  

  my $tastr=""; my $castr="";  my $flag=0;
  my $sufstr=""; my $retsuf="";  my $fullsufstr=""; 
  if (scalar(@ta)>0) { 
     $flag=1;
     $tastr = format_join(\@ta, ${CC_SEP}, $sp, "template < ", " >") ;
     $castr = format_join(\@ca, ${CC_SEP}, $sp, "template < ", " >") ;
  } elsif ($node->hasAttribute("template") || $node->hasAttribute("templatetype") ) {  
     $tastr ="template < >"; $castr ="template < >"; $flag=1;
  }
      
  $sufstr =format_join(\@suf,${CC_SEP}, $sp, "< ", " >") if (scalar(@suf)>0) ;
  $retsuf =format_join(\@pa, ${CC_SEP}, $sp, "< ", " >") if (scalar(@pa)>0);
  $fullsufstr=format_join(\@fullsuf,${CC_SEP}, $sp, "< ", " >") if (scalar(@fullsuf)>0);

  #print "CommonType:${tastr}\n";
  #print "CommonType:node=\n", $node->toString(1),"\n";
  
  return ($tastr, $castr, $sufstr, $retsuf, $fullsufstr, $flag);
}
############################################################################
sub isVirtual {
    return 0 unless ($_[0]->hasAttribute("virtual"));
    my $s0=$_[0]->getAttribute("virtual");
    return (is_true($s0) || ($s0 =~ /^pure$/i ) );
}
############################################################################
sub isInline {
    return 1 if (isXmlTrue($_[0],"inline"));
    return 0 if (isXmlFalse($_[0],"inline"));
    return 1 if ($_[0]->hasAttribute("impl"));
    foreach my $node ($_[0]->getChildrenByTagName("impl")) { return 1; };
    return 0;
}

sub isRealInline {
    return 1 if (isXmlTrue($_[0],"inline"));
    return 0 if (isXmlFalse($_[0],"inline"));
    return 1 if ($_[0]->hasAttribute("impl"));
    return 0;
}

# return implementation: a string array based on impl attribute and <impl> node
sub getImplStrings {
    my $node=$_[0];

    my @impl; my ($t1,$t2,$t3, $s0, $x0);
    if ($node->hasAttribute("impl")) {
       @impl=split("%n%", $node->getAttribute("impl"));
    }
    my $indCnt=0; my $indent=0; my $mysps="";
    foreach $t1 ($node->getChildrenByTagName("impl") ) { 
       if ($t1->hasAttribute("indent")) { 
          if (is_false($t1,"indent")) { $indent=-1; }
          else {$indent=0;}
       } else { $indent=1;}
       my $impltxt=trim($t1->textContent);
       foreach $t2 (split("\n",$impltxt)) {
          push(@impl, $t2);
       }
    }
    return @impl;
}
# <impl indent="true|false"></impl>
sub getMySpaces {
    my $cnt = int($_[0]);
    return "" if ($cnt<=0);
    return ${SP1}x${cnt};
}
###########################################################################

###########################################################################
=begin comment

sub genArgCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

sub genTypeCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

########## generate template str for class/function
sub genTemplateCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
=end comment
=cut
###########################################