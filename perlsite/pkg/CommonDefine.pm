package CommonDefine;

use strict;
use warnings;
use Exporter;

use XML::LibXML;

use Common qw( trim splitText $SP1 format_join );
use CommonXml qw( getXmlAttr splitXmlText xml_true xml_false);
use CommonType qw(getTypeStr getTemplateTypeStrs 
       getReturnStr getArgsStrings isInline isRealInline isVirtual getImplStrings);
use CommonMD5 qw(getMDLabels);

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( 
    genDeclCode genFriendDefCode genClassUsingCode
    genUsingCode genDefineCode genTypeDefCode 
    genEnumCode genUnionCode genVarCode genConstCode
    getFuncDeclStrs genFuncDefCode genFunctionCodes 
);

# these are exported by default.
our @EXPORT = qw( genDeclCode );
############################################################################
use XML::LibXML;
#use XML::LibXML qw(XML_ELEMENT_NODE);
###############################################################
my $CC_SEP=", ";
#header code for decl node
#  <friend class="list-of-classes" struct="list-of-structs" namespace="">
#      <class>classes</class>
#      <struct>structs</struct>
#      <function>function</function>
#      <cfunction>cfunction</cfunction>
#  </friend> 
#=>
#  friend class ns::xxx;
#  friend struct ns::xxx;
#  friend xxx;
#  friend extern "C" { xxx; }
#
sub genFriendDefCode{
    my $node=$_[0];  #decl node

    my @ha; my ($x0,$x1,$t1,$v0);
    my $ns=getXmlAttr($node,"namespace",""); $ns .="::" if ($ns);
    
    if ($node->hasAttribute("class")) {
       foreach $v0 (splitText($node->getAttribute("class"))) { 
          $x0 = "friend class ${ns}$v0;"; push(@ha, $x0);
       }
    }
    if ($node->hasAttribute("struct")) {
       foreach $v0 (splitText($node->getAttribute("struct"))) { 
          $x0 = "friend struct ${ns}$v0;"; push(@ha, $x0);
       }
    }

    foreach $t1 ($node->getChildrenByTagName("class")) {
       foreach $v0 (splitXmlText($t1)) { 
          $x0 = "friend class ${ns}$v0;"; push(@ha, $x0);
       }
    }  
    foreach $t1 ($node->getChildrenByTagName("struct")) {
       foreach $v0 (splitXmlText($t1)) { 
          $x0 = "friend struct ${ns}$v0;"; push(@ha, $x0);
       }
    }
    foreach $t1 ($node->getChildrenByTagName("function")) {
       $v0 = $t1->textContent; 
       $x0 = "friend $v0;"; push(@ha, $x0);
    }
    foreach $t1 ($node->getChildrenByTagName("cfunction")) {
       $v0 = $t1->textContent; 
       $x0 = "friend extern \"C\" {"; push(@ha, $x0);
       $x0 = "${SP1}${v0};"; push(@ha, $x0);
       $x0 = "}"; push(@ha, $x0);
    }

    #print "node:", $node->toString(1),":",$node->nodeType,"\n";
    $v0 = $node->textContent; # 	print "content:", $v0;  
	if ($v0) {
        if ($node->hasAttribute("cfunc") || $node->hasAttribute("func")) {
    	    if (xml_true($node, "cfunc") || xml_false($node, "func")) {
       			$x0 = "friend extern \"C\" {"; push(@ha, $x0);
       			$x0 = "${SP1}${v0};"; push(@ha, $x0);
       			$x0 = "}"; push(@ha, $x0);
        	} else {    	    	
    	    	 $x0 = "friend $v0;"; push(@ha, $x0);
        	}        	
        } else {
        	foreach $x1 (splitText($v0)) { 
          		$x0 = "friend class ${ns}$v0;"; push(@ha, $x0);
        	}
        }    	      
	} 
	
    return \@ha;
}

########################################################################
#header code for using namespace xxx
#header code for using node
#  <using alias="alias" namespace="ns"/>
#  <using namespace="true|false">list-of-namespaces </using>
#=>
#  using xxx; #within class
#  using namespace xxx;
#  using namespace xxx as alias;
#
sub genUsingCode {
    my $node=$_[0];  #using node
    my @ha; my ($x0,$x1,$x2,$t1,$v0);
    
    if ($node->hasAttribute("alias") && $node->hasAttribute("namespace")) {
          $x1=$node->getAttribute("namespace"); $x2=$node->getAttribute("alias");
          $x0 = "using namespace $x1 as $x2;"; push(@ha, $x0);
    }

    my $ns="namespace"; $ns="" if (xml_false($node,"namespace"));
    foreach $t1 (splitXmlText ($node)) {
       $x0 = "using $ns $t1;"; push(@ha, $x0);
    }

    return \@ha;
}

# using xxx; in class
sub genClassUsingCode {    
    my $node=$_[0];  #using node
    my $x0 = $_[0]->textContent;
    return "${SP1}using $x0;";
}

#header code for decl node
#  <decl class="list-of-classes" struct="list-of-structs" 
#    isclass="true|false" namespace="" friend="true|false">
#    list-of-classes
#    <type>*
#    <function>*
#  </decl>
#=>
#  [friend] class ns::xxx;
#  [friend] struct ns::xxx;
#
sub genDeclCode {
    my $node=$_[0];  #decl node

    my @ha; my ($x0,$x1,$t1,$v0);
    my $ns=getXmlAttr($node,"namespace",""); $ns .="::" if ($ns);
    my $p=""; $p="friend " if (xml_true($node, "friend"));
    
    if ($node->hasAttribute("class")) {
       foreach $v0 (splitText($node->getAttribute("class"))) { 
          $x0 = "${p}class ${ns}$v0;"; push(@ha, $x0);
       }
    }
    if ($node->hasAttribute("struct")) {
       foreach $v0 (splitText($node->getAttribute("struct"))) { 
          $x0 = "${p}struct ${ns}$v0;"; push(@ha, $x0);
       }
    }
    foreach $t1 (splitXmlText ($node)) {
       $x0 = "${p}class ${ns}$t1;"; push(@ha, $x0);
    }
    
    # template type:
    my $category="${p}struct ";
    $category="${p}class " if (xml_true($node,"isclass"));

    foreach $t1 ($node->getChildrenByTagName("type")) {
       $x0 = getTypeStr($t1); push(@ha, "${category}${ns}$x0;");
    }
    $category="friend ";
    foreach $t1 ($node->getChildrenByTagName("function")) {
       ($x0, $x1)= getFuncDeclStrs($t1); push(@ha, "${category}${ns}$x0;");
    }
    return \@ha;
}
########################################################################
# return function string for header; source code and signature
# class method: add attributes: access; const; virtual; class_template
########################################################################
sub getFuncDeclStrs {
    my $node=$_[0];
    my $sp=""; $sp=$_[1] if ($_[1]);
    
    my $prefix=getXmlAttr($node,"prefix","");
    $prefix=getXmlAttr($node,"class_name",$prefix);
    my $cls_template=getXmlAttr($node, "pre_template", "");
    $cls_template=getXmlAttr($node,"class_template",$cls_template);
    
    my $name=$node->getAttribute("name"); 
    my $fname="${prefix}${name}";
    my @sn=getTemplateTypeStrs($node);
    my $th=""; $th ="${sp}$sn[0]\n" if ($sn[0]);
    my $tc=""; $tc ="$sn[1]\n" if ($sn[1]); 
    $tc ="${cls_template}\n${tc}" if ($cls_template);
    
    my $suf=$sn[3];

    my $ret=""; my $retflag=1;
    if ($node->hasAttribute("return")) {
       my $a1=$node->getAttribute("return");
       if ($a1 =~ /^none$/i) { $retflag=0; }
    }
    if ($retflag) {
        $ret = getReturnStr($node) ;
        $ret="void" unless ($ret);
    }
    my $cret="";
    if ($ret){
        $cret=$ret; $cret="inline $ret" if (isInline($node) );
        $ret="static $ret" if (xml_true($node,"static"));
        $ret="virtual $ret" if (isVirtual($node));
        if (isRealInline($node) && $node->nodeName eq 'function') { $ret="inline $ret"; } 
        $ret.=" "; $cret.=" ";
    } else {  #constructors/deconstructor
        if (isVirtual($node)) { $ret="virtual "; }
        if (isInline($node)) { $cret="inline "; }
    } 

    my ($argha, $argca, $argsa) = getArgsStrings($node);
    my $throws=getXmlAttr($node,"throw","");
    $throws=" throw ( $throws )" if ($node->hasAttribute("throw"));
    my $const=""; $const=" const" if (xml_true($node,"const"));
    
    my $fh0="${th}${sp}${ret}${name}${suf}( ";  
    my $fc0="${tc}${cret}${fname}${suf}( ";
    my $fn=")${const}${throws}";  my $fcn=")${const}${throws}";
    my $mysp="${SP1}${sp}";

    my $hs = format_join($argha, ${CC_SEP}, $mysp, $fh0, $fn);
    my $cs = format_join($argca, ${CC_SEP}, $mysp, $fc0, $fcn);

    #signaure
    my $s0 = "";  $s0=join(${CC_SEP}, @{$argsa} ) if ($argsa);
    my $ss = "${name}${suf}($s0)${const}";
    #print "function:", $node->toString(1), "\n", "inline:", isInline($node);
    return ($hs, $cs, $ss, $sn[5]);
}
########################################################################
sub genFuncDefCode {
  my $node = $_[0];
  my $sp="";  $sp = $_[1] if ($_[1]);
  
  my @st=getFuncDeclStrs($node,$sp);
  return "${sp}typedef ${st[0]};";
}

########################################################################
sub genFunctionCodes  {
   my $node=$_[0];
   my $sp="";     $sp = $_[1] if ($_[1]);
   my %codes=();  %codes=%{$_[2]} if ($_[2]);  
   
   my $initStr=getXmlAttr($node,"init", "");
   my ($hs,$cs,$ss, $ntmp) =getFuncDeclStrs($node,$sp);
   my ($mds1, $mds2, $mds3)=getMDLabels($ss);
   
   if ($node->hasAttribute("virtual") && $node->getAttribute("virtual") eq "pure") {
     return ("$hs = 0", "", $ss, $mds3, $ntmp);
   }
   
   my $ccode=""; $ccode="${mds1}\n$codes{$mds3}${mds2}" if ( %codes && (exists ($codes{$mds3}) ) ) ;

   unless ($ccode){ #no customized code
      my @cimpl=getImplStrings($node);  
      if (scalar(@cimpl)<=0) {  $ccode="${mds1}\n${mds2}" unless (isInline($node));}
      else { 
         my $msp="${sp}${SP1}";
         unless (isInline($node)) { $msp="${sp}"; };
         $ccode=$msp.join("\n$msp",@cimpl); 
         #print "msp=${msp};sp=${sp};\n";
      }
   }
   ${ccode} .="\n" if ($ccode);
    
   if (isRealInline($node)) { # no source codes
       #print "inline sp=${sp};init=${initStr};\n";
       $initStr="\n${sp}${initStr}" if ($initStr);
       $hs = "$hs${initStr}\n${sp}{\n${ccode}${sp}}";
       return ($hs, "", $ss, $mds3, "");
   } else {
       $initStr="\n${initStr}" if ($initStr);
       $cs = "$cs${initStr}\n{\n${ccode}}\n";
       return ($hs, "", $ss, $mds3, $cs) if ($ntmp || isInline($node)); 
       return ($hs, $cs, $ss, $mds3, "");
   }
}

#header code for using namespace xxx
#  <var name="name" type="" static="" const="" value=""/> 
#  using namespace xxx;
#  using namespace xxx as alias;
#
sub getVarPrefix {
    my $node=$_[0];
    my $sp="";  $sp=$_[1] if ($_[1]);

   my $psa=$sp; $psa .= "static " if (xml_true($node,"static"));
   $psa .= "const " if (xml_true($node,"const") || ($node->nodeName eq "const")) ;
   
   my $ref=" ";  $ref = " & " if (xml_true($node,"ref")) ;
   
   return ($psa, $ref);
}
sub genVarCode {    
    my $node=$_[0];
    my $sp="";  $sp=$_[1] if ($_[1]);
    
    my ($sap, $ref)= getVarPrefix ($_[0], $sp);
    
    my $t0 = $node->getAttribute("type");
    my $n0 = $node->getAttribute("name");
   
    if ($node->hasAttribute("array")) {
       my $t1=$node->getAttribute("array");
       $n0 .= "[${t1}" unless ($t1 =~ m/^\[/);
       $n0 .= "]" unless ($t1 =~ m/\]/);
    }
    my $sa="$sap$t0$ref$n0";
    
    my $x0=getXmlAttr($node,"value","");
    $x0=getXmlAttr($node,"default","") if (length($x0)==0);
    if ($node->textContent()) { $x0 .="\n"; $x0 .= $node->textContent();}
    
    print "var value=${x0}\n";
    
    return ($sa.";", "") if (length($x0)==0);
    my $init= xml_true($node,"const") || ($node eq "const") || xml_true($node,"static");
    #return ("$sa = $x0;", "") if (isInteger($t0) && $init );  #integer

    $x0= "\"$x0\"" if (xml_true($node,"string"));
    return ("$sa = $x0;", "") if (xml_true($node,"inline"));  #inline
    
    my $sc="$sap$t0${ref}$n0=$x0;";

    if (xml_true($node,"init")) { return ($sc,""); }
    else { return ($sa.";", $sc ); }  
}
sub genConstCode { return genVarCode($_[0]);} 
#header code for define node
############################################################################
# <define name="name" args="args">
#    <item value="" />
# </define>
#=>
##ifndef name
##if cond
##define name(args)  \
#  item1             \
#  itemn
##else if cond
#
##endif
############################################################################
sub genDefineCode {
  my $node = $_[0];
  my $sp="";  $sp = $_[1] if ($_[1]);
  
  my $name=uc(trim($node->getAttribute("name")));
  
  # define NAME VALUE
  if ($node->hasAttribute("value")) {
     my $val=getXmlAttr($node,"value");
     return "${sp}#define $name $val";
  }
  
  my $args=getXmlAttr($node,"args","");
  $args=getXmlAttr($node,"arg","") unless ($args);
  $args="($args)"if ($args);
  
  my @ha;  my $s0="#define $name$args"; 
  my $x0; my $x1; my $x2; my $cnt=0;
  foreach my $t1 ($node->getChildrenByTagName("if")) {
     if ($cnt==0) {
        $x1=$t1->getAttribute("condition");
        $x0="${SP1}#if $x1"; push(@ha,$x0);
     } else {
        if ($t1->hasAttribute("condition")) {  $x1=$t1->getAttribute("condition"); $x0="${SP1}#elif $x1"; } 
        else { $x0="${SP1}#else";  }
        push(@ha,$x0);
     }
     
     my @def0;  push(@def0,$s0);
     foreach my $x1 ($t1->getChildrenByTagName("item")) {
       push(@def0, $x1->getAttribute("value")) if ($x1->hasAttribute("value"));
       my $s1=trim($x1->textContent()); push(@def0,$s1) if ($s1);
     }
     $x0=join(" \\\n${sp}${SP1}${SP1}", @def0);
     push(@ha,$x0); $cnt+=1;
  }
  if ($cnt>0) { $x0="#else"; push(@ha,$x0);}
  
  my @def1;  push(@def1,$s0);
  foreach my $t1 ($node->getChildrenByTagName("item")) {
        push(@def1, $t1->getAttribute("value")) if ($t1->hasAttribute("value"));
        my $s1=trim($t1->textContent()); push(@def1,$s1) if ($s1);
  }
  
  $x0=join(" \\\n${sp}${SP1}", @def1); push(@ha, $x0);
  if ($cnt>0) { $x0="#endif"; push(@ha,$x0);}
  
  $s0=join(" \n${sp}${SP1}", @ha);
  return "${sp}#ifndef ${name}\n${s0}\n#endif\n";
}
############################################################################


############################################################################
# <typedef name="name" type="type" class="" templatetype="" typedef="" typename="t|f">
#    <templatetype/>*
# </typedef>
#=>
# typedef type name;
############################################################################
sub genTypeDefCode {
  my $node = $_[0];
  my $sp="";  $sp = $_[1] if ($_[1]);
  
  my $name=getXmlAttr($node,"name","");
  my $type=getTypeStr($node);

  return "${sp}typedef $type ${name};";
}

###############################################################
sub genEnumCode {
  my $node=$_[0];
  my $sp="";  $sp = $_[1]  if ($_[1]) ;
  
  my $name=getXmlAttr($node,"name","");
  my ( $x0, $x1, @ha);
  foreach my $t1 ($node->getChildrenByTagName("item")) {
    if ($x0=$t1->hasAttribute("name")) { 
       $x0=$t1->getAttribute("name");
       if ($t1->hasAttribute("value")) {  
          $x1=$t1->getAttribute("value");
          if (xml_true($t1,"quot")) { push(@ha, "${sp}${SP1}$x0=\'$x1\'");}  
          else { push(@ha, "${sp}${SP1}$x0=$x1"); } 
       } else {   push(@ha, "${sp}${SP1}$x0"); }
    } else { $x0=$t1->getAttribute("value"); push(@ha, "${sp}${SP1}$x0"); }  
  }
  $x1=join(",\n",@ha);
  if (xml_false($node, "typedef")) { $x0="${sp}enum ${name} {\n$x1\n${sp}};\n"; }
  else { $x0="${sp}typedef enum {\n$x1\n${sp}} ${name};\n"; }  
  return $x0;
}

sub genUnionCode {
  my $node=$_[0];
  my $sp="";  $sp = $_[1]  if ($_[1]) ;

  my $name=$node->getAttribute("name");
  my ( $x0, $x1, @ha, @haenum);
  $x0="${sp}union ${name} {"; push (@ha, $x0);
  
  foreach my $t1 ($node->getChildrenByTagName("item")) {
       $x0=$t1->getAttribute("type");
       if ($t1->hasAttribute("name")) {  $x1=$t1->getAttribute("name"); }
       else {$x1=lc($x0);}
       
       push(@ha, "${sp}${SP1}$x0 $x1;"); 
       $x1=uc($x0);  $x1 =~ s/\s/\_/g; $x1 =~ s/\*/PTR/g;    
       push(@haenum, "${sp}${SP1}${x1}_TYPE"); 
  }
  push (@ha, "${sp}}"); 
  $x0=join("\n",@ha); 
  
  if (xml_true($node, "enum")) { 
     $x1 = join(",\n",@haenum);
     $x0 .= "\n${sp}enum ${name}Type {\n$x1\n};"; 
  }
  
  return $x0;
}
############################################################################
1
############################################################################
