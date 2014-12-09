package CommonClass;

use strict;
use warnings;
use Exporter;
use XML::LibXML;

our $DEBUG;

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( genClassCode );

# these are exported by default.
our @EXPORT = qw( genClassCode );

use XML::LibXML qw(XML_ELEMENT_NODE);

use Common qw($SP1 $SP2 $CC_SEP trim contains onlySplitText 
              is_true is_false format_join );
use CommonXml qw(xml_true copyAttrsTo getXmlAttr splitXmlText);
use CommonMD5 qw(getMDLabels);
use CommonType qw(getTypeStr getTemplateTypeStrs isVirtual);
use CommonDefine qw(
    genDeclCode genFriendDefCode genUsingCode 
    genDefineCode genTypeDefCode genClassUsingCode
    genEnumCode genUnionCode genVarCode genConstCode
    genFunctionCodes 
); 
use CommonMember qw( getVarAccessCodes getMemberDeclStr );

####################################################
# common-used subroutines related to class node
####################################################
############################################################################
# <class>
#     <parent></parent>
#     <template></template>
#     <templatetype></templatetype>
#     <friend></friend>
#     <public></public>:       classItem
#     <protected></protected>: classItem
#     <private></private>:     classItem
# </class>
# <classMember>
#     <typedef/>
#     <enum/>
#    <field>
#       <const/>
#       <vars/>
#       <count/>
#       <config/>
#       <metric/>
#    <method>
#       <constructor/>
#       <deconstructor/>
#       <operator/>
#       <cast/>
#       <method/>
# <classMember>
############################################################################

############################################################################
# getClassCode.pl
# input:
#   arg0: class node
#   arg1: customized codes map
#   arg2: interfaces map
# return:
#   ret1: list of headder codes 
#   ret2: list of cc codes 
#   ret3: list of inline cc codes 
#
#order of C++ code:
# extern C functions
# template <templates>
# class name<templatetypes> 
#  : parents
# {
#   friend classes;
#   friend functions 
# [public|protected|private:]
#   typedef
#   enum {}
# [public|protected|private:]
#   const
#   static operators
#   static methods
#   static access methods
#   static members
#
#   constructors
#   instance operators, casts
#   instance methods
#   instance access methods
#   instance members
# }
# inline implementation.
#
sub genClassCode { #($cls, \%codes; %mcodes ); for class node.
  my $cls=$_[0];        #expandClass($_[0]);
  my $codes=$_[1];      #%codes 
  my $interfs=$_[2];    #%interface
  
  my (@ca, @ha, @ham);
  ################################################### body
  my $cnode=expandClass($cls,$interfs);
  if ($DEBUG) {  print "expanded class:\n", $cnode->toString(1), "\n"; }
  
  ######################################### extern "C" typedef;
  my ($t1,$t2,$t3, $x0, $x1,$x2,$x3,$x4,$x5);
  
  my @defa;  #only for extern "c"
  foreach $t1 ($cnode->getElementsByTagName("typedef")) {
      push(@defa, genTypedefStr($t1)) if (xml_true($t1, "c"));
  }
  if (@defa) { 
     push(@ha, "extern \"C\""); push(@ha, @defa); push(@ha, "};");
  }
  
  #############################################################
  #template info: 
  # s1: template <typename T1, ..., typename Tn=default>
  # s2: template <typename T1, ..., typename Tn>
  # s3: <T1, ..., Tn> # real templates
  # s4: <P1,..., Pm>  # partial parameterized
  # s5: <T1,...,Tn,P1,...,Pm>
  # s6: number of real templates: 
  my ($st0,$st1,$st2,$st3,$st4,$st5) = getTemplateTypeStrs($cls);
  push(@ha,$st0) if ($st0);     ###  template decl

  ######################################### templatetype info;
  my $name = $cls->getAttribute("name");
  # for internal classes: xxx::class
  my $prename=getXmlAttr($cls, "prefix",""); $prename .="::" if ($prename); 
  my $clsname="${prename}${name}${st4}";
  
  my $mod="class"; my $daccess="protected";
  if ( xml_true($cls, "struct") ){ $mod="struct"; $daccess="public"; }
  if ($st3) { push(@ha, "${mod} ${name} $st4 "); }  ###  class decl
  else { push(@ha, "${mod} ${name} "); }
  
  ##############################################
  my $haparent = genParentsCode($cnode);
  push(@ha,$haparent) if ($haparent);   ###  parent decl
  ##############################################

  ##############################################
  push(@ha, "{");   # start class
  ##############################################

  ## friend functions for iput/output
  if ($cls->hasAttribute("input")) {
    $x0 = "friend std::istream & operator>>(std::istream & in, ${name} & obj)\n{"; push(@ha, $x0);
    $x0="${SP1}obj.input(in);\n${SP1}return in;\n}"; push(@ha, $x0);
  }
  if ($cls->hasAttribute("output")) {
    $x0 = "friend std::ostream & operator<<(std::ostream & out, const ${name} & obj)\n{"; push(@ha, $x0);
    $x0="${SP1}obj.output(out);\n${SP1}return out;\n}"; push(@ha, $x0);
  }

  ######################################### typedef & enum & decl & using
  my $acc=$daccess; my $flag=0;
  my @PREDEF_MEMBERS=("use","using","decl","typedef","enum","union","class", "friend");
  foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      next unless (contains($t1->nodeName, \@PREDEF_MEMBERS));
      
      my $p0=getXmlAttr($t1,"access",$daccess);
      if ($flag==0) {$acc=$p0; push(@ha, "${acc}:"); $flag=1;}
      elsif ($p0 ne $acc) { $acc=$p0; push(@ha, "${acc}:");}
      if ($t1->nodeName eq "use")       { push(@ha, genClassUsingCode($t1, $SP1)); }
      elsif ($t1->nodeName eq "using")  { push(@ha, genClassUsingCode($t1, $SP1)); }
      elsif ($t1->nodeName eq "decl")   { push(@ha, @{genDeclCode($t1,$SP1)}); }
      elsif ($t1->nodeName eq "friend") { push(@ha, @{genFriendDefCode($t1, $SP1)});}
      elsif ($t1->nodeName eq "typedef"){ push(@ha, genTypeDefCode($t1, $SP1));}
      elsif ($t1->nodeName eq "enum")   { #enum code; set prefix 
        push(@ha, genEnumCode($t1, $SP1)); $t1->setAttribute("prefix",$clsname);
      } elsif ($t1->nodeName eq "text"){ 
        my $txt=trim($t1->textContent); $txt .="\n" if ($txt);
        if (xml_true($t1,"c") || xml_true($t1,"c")) {push(@ca, $txt);}
        else { push(@ha, $txt); }
      }
      #elsif ( ($t1->nodeName eq "class") or ($t1->nodeName eq "struct") ){ }
      #elsif ($t1->nodeName eq "union"){}
      else { print "*** UNKNOWN node ", $t1->nodeName, "\n";}
  }

  my $initHaStr=getClassInitStrs($cnode, ${SP2});
  my $initCaStr=getClassInitStrs($cnode, ${SP1});
  my @fullname=($st0, $st1, $clsname, $name, $initHaStr, $initCaStr); 
  
  ## constructors; methods;  operators; casts; variables
  my $sp="${SP1}"; my $pre="";
  my @CLASS_MEMBERS=("const","var","count","config","profile");
  my @CLASS_MEMBERS_NOCONST=("const", "var","config","count","profile");
  #variable access methods; static-protected;static-private;class-protected;class-private;
  my @sha; my @sca; my @cha; my @cca;
  foreach $t2 (@CLASS_MEMBERS) {
     foreach $t1 ($cnode->getChildrenByTagName($t2) ) {
        next if (matchAccess($t1, "public"));
        
        ($x0,$x1,$x2)= getVarAccessCodes(\@fullname, $t1, $SP1);
        if ( xml_true($t1,"static") ) { push(@sha, @{$x0}) if ($x0); push(@sca, @{$x1}) if ($x1);} 
        else { push(@cha, @{$x0}) if ($x0); push(@cca, @{$x1}) if ($x1); }
     }
  }
  
  foreach my $access ("public","protected","private") {
     my (@myha, @myca); my (@myha0, @myca0);

     ##########################
     # static variables: const;
     my $flag=0;
     foreach $t1 ($cnode->childNodes) {
        next if ($t1->nodeType != XML_ELEMENT_NODE);
        next unless (contains($t1->nodeName, \@CLASS_MEMBERS));
        next unless (matchAccess($t1, $access));
        
        if ( ($t1->nodeName eq "const") || xml_true($t1,"const") ) {
             ($x1,$x2) = getMemberDeclStr(\@fullname, $t1, $SP1); 
             push(@myha, $x1) if ($x1);  push(@myca, $x2) if ($x2); 
             $flag=1; 
        }
     }
     if ($flag) { push(@myha, "");}
     
     # static variables: non-const
     $flag=0;
     foreach $t1 ($cnode->childNodes) {
        next if ($t1->nodeType != XML_ELEMENT_NODE);
        next unless (contains($t1->nodeName,\@CLASS_MEMBERS_NOCONST));
        next unless (matchAccess($t1, $access));
        if ( xml_true($t1,"static") ) {
             next if ( ($t1->nodeName eq "const") || xml_true($t1,"const") );
             ($x1,$x2) = getMemberDeclStr(\@fullname, $t1, $SP1); 
             push(@myha, $x1) if ($x1); push(@myca, $x2) if ($x2); $flag=1; 
        }
     }
     if ($flag) {push(@myha, "");}
     
     #internal class/struct
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("class") ) {
        next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2) = genClassCode($t1, $codes, $_[2]); # \%mcodes) ;
        push(@myha, @{$x0}); $flag=1;
        if ($st1) { push(@ham,  @{$x1}) if ($x1); }
        else {  push(@myca,  @{$x1}) if ($x1); }
        push(@ham,  @{$x2}) if ($x2);
     }
     if ($flag) {push(@myha, "");}
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("struct") ) {
        next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2) = genClassCode($t1, $codes,$_[2]); # \%mcodes)  ;
        push(@myha, @{$x0}); $flag=1;
        if ($st1) { push(@ham,  @{$x1}) if ($x1); }
        else {  push(@myca,  @{$x1}) if ($x1); }
        push(@ham,  @{$x2}) if ($x2);
     }
     if ($flag) {push(@myha, "");}
     
     #static_variables-access-methods
     $flag=0;
     if ($access eq "public" ) { 
        if ( scalar(@sha)>0) { push(@myha, @sha); $flag=1;} 
        push(@myca, @sca) if ( scalar(@sca)>0); 
     }
     if ($flag) {push(@myha, "");}
     
     #static_methods;
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("method") ) {
        next unless (matchAccess($t1, $access)); next unless (xml_true($t1,"static"));
        ($x0, $x1, $x2, $x3, $x4, $x5) = genMethodStrs(\@fullname, $t1, $SP1, $codes); #\%mcodes) ;
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1); }
        else {  push(@myca,  $x1) if ($x1); }
        push(@ham,  $x4) if ($x4);
     }
     if ($flag) {push(@myha, "");}
     
     #static_operators;
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("operator") ) {
        next unless (matchAccess($t1, $access)); next unless (xml_true($t1,"static"));
        ($x0, $x1, $x2, $x3, $x4, $x5) = getOperatorCodes(\@fullname, $t1, $SP1, $codes); # \%mcodes) ;
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1); }
        else {  push(@myca,  $x1) if ($x1); }
        push(@ham,  $x4) if ($x4);
     }
     if ($flag) {push(@myha, "");}
     
     #constructors
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("constructor") ) {
        next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2, $x3, $x4, $x5) = genConstructorCodes(\@fullname,$t1,${SP1}, $codes); # \%mcodes) ;
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1); }
        else {  push(@myca,  $x1) if ($x1); }
        push(@ham,  $x4) if ($x4); 
     }
     #deconstructor
     foreach $t1 ($cnode->getChildrenByTagName("deconstructor") ) {
        next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2, $x3, $x4, $x5) = genDeconstructorCodes(\@fullname, $t1,$SP1,$codes); # \%mcodes);
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1); }
        else {  push(@myca,  $x1) if ($x1); }
        push(@ham,  $x4) if ($x4);
     }
     if ($flag) {push(@myha, "");}
          
     #non-const_static_variable;
     $flag=0;
     if ($access eq "public" ) {
         if ( scalar(@cha)>0) { push(@myha, @cha); $flag=1;} 
         push(@myca, @cca) if ( scalar(@cca)>0); 
     }
     if ($flag) {push(@myha, "");}
     
     ##########################
     # non-static variables
     $flag=0;
     foreach $t2 (@CLASS_MEMBERS) {
        foreach $t1 ($cnode->getChildrenByTagName($t2) ) {
           next if ($t1->nodeName eq "const");  next if ( xml_true($t1, "const"));
           next if (xml_true($t1,"static")); next unless (matchAccess($t1, $access));
           ($x1,$x2) = getMemberDeclStr(\@fullname, $t1, $SP1); 
            push(@myha, $x1); $flag=1;  #push(@myca, $x2);
        }
     }
     if ($flag) {push(@myha, "");}
     #non-static variable-access methods
     
     #non-static methods
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("method") ) {
        next if (xml_true($t1,"static")); next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2, $x3, $x4, $x5) = genMethodStrs(\@fullname, $t1,$SP1, $codes); #\%mcodes);
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1); }
        else {  push(@myca,  $x1) if ($x1); }
        push(@ham,  $x4) if ($x4); 
     }
     if ($flag) {push(@myha, "");}

     #operators
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("operators") ) {
        next unless (matchAccess($t1, $access));
        ($x0, $x1, $x2, $x3, $x4) = genOperatorCodes(\@fullname, $t1,$SP1, $codes); #\%mcodes);
        $x0 .= ";";  push(@myha, $x0); $flag=1;
        if ($st1) { push(@ham,  $x1) if ($x1);}
        else {  push(@myca,  $x1) if ($x1); }
         push(@ham,  $x4) if ($x4);
     }
     if ($flag) {push(@myha, "");}
          
     #casts
     $flag=0;
     foreach $t1 ($cnode->getChildrenByTagName("casts") ) {
        next unless (matchAccess($t1, $access));
        foreach $t2 ($t1->getChildrenByTagName("cast")) {
            ($x0, $x1, $x2, $x3,$x4) = genCastCodes(\@fullname, $t2,$SP1,$codes);# \%mcodes) ;
            $x0 .= ";";  push(@myha, $x0); $flag=1;
            if ($st1) { push(@ham,  $x1) if ($x1);  }
            else {  push(@myca,  $x1) if ($x1); }
            push(@ham,  $x4) if ($x4);
        }
     }
     #non-static-variables
     if (scalar(@myha)>=1) { $x1="${pre}${access}:"; push(@ha, $x1); push(@ha, @myha); $pre="\n";}
     if (scalar(@myca)>=1) { push(@ca, @myca);}
  }
  
  #none constructors or deconstructors
  #constructors
  my @noneha;
  foreach $t1 ($cnode->getChildrenByTagName("constructor") ) {
     next unless (matchAccess($t1, "none"));
     ($x0, $x1, $x2) = genConstructorCodes(\@fullname,$t1,${SP1}, $codes); #\%mcodes) ;
     push(@noneha, $x0.";");
  }
  foreach $t1 ($cnode->getChildrenByTagName("deconstructor") ) {
     next unless (matchAccess($t1, "none"));
     ($x0, $x1, $x2, $x3) = genDeconstructorCodes(\@fullname, $t1,$SP1, $codes); #\%mcodes);
     push(@noneha, $x0.";");
  }
  foreach $t1 ($cnode->getChildrenByTagName("method") ) {
     next unless (matchAccess($t1, "none"));
     ($x0, $x1, $x2, $x3, $x4, $x5) = genMethodStrs(\@fullname, $t1, $SP1, $codes); #\%mcodes) ;
     push(@noneha, $x0.";");
  }
  if (scalar(@noneha)>0) { push(@ha, "\nprivate:");  push(@ha, @noneha); }
     
  
  ############################################################################
  
  ###########  extra signature for class.
  if (xml_true($cls,"ext") || xml_true($cls, "extension") ) {
     push(@ha,getLabelStr("${name}$st1", $codes));
  }
  
  ##############################################
  $x1="};\n"; push(@ha, $x1);

  #print "save cc:@ca; ", scalar(@ca),"\n";
  return(\@ha, \@ca, \@ham);    
}
############################################################################
###############################################################
my @NODE_NAMES=( "constructors","methods", "typedefs"); #typedefs: typedef, enum
my @CLASS_MEMBERS=("const","var","count","config","profile");

sub matchAccess { #($t1, $access)
   my $a=$_[0]->getAttribute("access");
   return $a eq $_[1];
}

sub hasSharedNames { # name attr could be a list of names.
   return ( ($_[0]->nodeName eq "var") || 
            ($_[0]->nodeName eq "method") || 
            ($_[0]->nodeName eq "cast") ||
            ($_[0]->nodeName eq "typename") );
}

sub expandClass { # only for members; and constructors
    my $cls=$_[0]; 
    my %ifs; %ifs=%{$_[1]} if ($_[1]);
    
    my ($t0,$t1, $t2, $t3, $t4, $t5, $access);
  
    my $node = copyAttrsTo($cls, $cls->cloneNode(0));
    my $daccess="protected";  $daccess="public" if ( xml_true($cls, "struct"));
    $daccess=$cls->getAttribute("access") if ($cls->hasAttribute("access"));
  
    my $maccess="public"; 
    $maccess=$cls->getAttribute("maccess") if ($cls->hasAttribute("maccess"));
    #print "cls node:",$cls->toString(1);
    
    my $name=$node->getAttribute("name");
    if ($cls->hasAttribute("default")) {  # default constructor
        $t1=$node->ownerDocument->createElement("constructor");
        $t1->setAttribute("access", $cls->getAttribute("default"));
        $node->addChild($t1);
    }
    if ($cls->hasAttribute("copy")) {     # copy constructor
        $t1=$node->ownerDocument->createElement("constructor");
        $t1->setAttribute("access", $cls->getAttribute("copy"));

        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("name", "obj");   $t2->setAttribute("type", $name);
        $t2->setAttribute("const", "true"); $t2->setAttribute("ref", "true");
        $t1->addChild($t2); $node->addChild($t1);
    }
    if ($cls->hasAttribute("assign")) {   # assign operator
        $t1=$node->ownerDocument->createElement("method");
        $t1->setAttribute("name", "operator=");
        $t1->setAttribute("access", $cls->getAttribute("assign"));
        
        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("name", "obj");   $t2->setAttribute("type", $name);
        $t2->setAttribute("const", "true"); $t2->setAttribute("ref", "true");

        $t3=$node->ownerDocument->createElement("return");
        $t3->setAttribute("class", $name);   $t3->setAttribute("ref", "true");

        $t1->addChild($t2); $t1->addChild($t3); $node->addChild($t1);
        #print "assign node:",$t1->toString(1);
    }
    #if ($cls->hasAttribute("input")) {
    #    $t1=$node->ownerDocument->createElement("method");
    #    $t1->setAttribute("name", "input");
    #    $t2=$node->ownerDocument->createElement("arg");
    #    $t2->setAttribute("type", "std::istream");   $t2->setAttribute("ref", "true");
    #    $t2->setAttribute("name", "in");   $t1->addChild($t2); 
    #    $node->addChild($t1);
    #}
    #if ($cls->hasAttribute("output")) {
    #    $t1=$node->ownerDocument->createElement("method");
    #    $t1->setAttribute("name", "output"); $t1->setAttribute("const", "true");
    #    $t2=$node->ownerDocument->createElement("arg");
    #    $t2->setAttribute("type", "std::ostream");   $t2->setAttribute("ref", "true");
    #    $t2->setAttribute("name", "out");   $t1->addChild($t2); 
    #    $node->addChild($t1);
    #}

    if ($cls->hasAttribute("impl")) {  #implement the interfaces; public and virtual methods
        foreach $t1 (splitText($cls->getAttribute("impl"))) {
           $t1=trim($t1); next unless ($t1);
           unless (exists $ifs{$t1}) { print "class $name implemented interface $t1 not exists\n"; }
           foreach $t2 (@{$ifs{$t1}}) {
              foreach $t3 ($t2->getChildrenByTagName("method")) {
                  $t4=$t3->cloneNode(1); $t4->setAttribute("access","public");
                   $t4->setAttribute("virtual","true"); $node->addChild($t4);
              }
           }
           
           $t2=$node->ownerDocument->createElement("parent");
           $t2->setAttribute("virtual","true"); $t2->setAttribute("access","public");
           $t2->setAttribute("type",$t1);$node->addChild($t2);
        }
    }

    foreach $t1 (@{$cls->childNodes}) {  
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      
      if ($t1->nodeName eq "group") {  # group of elements
         foreach $t2 ($t1->childNodes) {
            next if ($t2->nodeType != XML_ELEMENT_NODE);
            if ( hasSharedNames($t2) ) {
               if ($t2->hasAttribute("name")) {
                  foreach $t3 (onlySplitText($t2->getAttribute("name"))) {
                     $t4=$t2->cloneNode(1); $t4->setAttribute("name",$t3);
                     $node->addChild( copyAttrsTo($t1, $t4));
                  }
               }
               if ($t2->hasAttribute("names")) {
                  foreach $t3 (onlySplitText($t2->getAttribute("names"))) {
                     $t4=$t2->cloneNode(1); $t4->setAttribute("name",$t3);
                     $node->addChild( copyAttrsTo($t1, $t4));
                  }
               }
            } else {
               $node->addChild( copyAttrsTo($t1, $t2->cloneNode(1)));
            }
         }
      } elsif ( hasSharedNames($t1)  && ($t1->hasAttribute("name")) ) { 
         foreach $t3 (onlySplitText($t1->getAttribute("name"))) {
            $t4=$t1->cloneNode(1); $t4->setAttribute("name",$t3);
            $node->addChild($t4);
         }
      } elsif ($t1->nodeName eq "impl") {  # implement interfaces
         foreach $t2 (splitXmlText($t1)) {
            if (!exists $ifs{$t2}) { print "*** WARNING: interface $t2 not exists\n"; next; }
            
            foreach $t3 (@{$ifs{$t2}}) {
                foreach $t4 ($t3->getElementsByTagName("method")) {
                    $t5=$t4->cloneNode(1); 
                    $t5->setAttribute("virtual",getXmlAttr($t1, "virtual", "true"));
                    unless ($t5->hasAttribute("access")) { 
                        $t5->setAttribute("access",getXmlAttr($t1, "access", getXmlAttr($t3,"access","public"))) ;
                    }
                    $node->addChild($t5);
                }
            }
            $t3=$node->ownerDocument->createElement("parent");
            $t3->setAttribute("virtual",getXmlAttr($t1, "virtual", "true")); 
            $t3->setAttribute("access",getXmlAttr($t1, "access", "public"));
            
            $t3->setAttribute("type",$t2);$node->addChild($t3);
            
         }
      } elsif ($t1->nodeName eq "interface") {  # interfaces; switch to method
         foreach $t4 ($t1->getElementsByTagName("method")) {
              $t5=$t4->cloneNode(1); 
              $t5->setAttribute("virtual",getXmlAttr($t1, "virtual", "pure")) unless ($t5->hasAttribute("virtual")); 
              $t5->setAttribute("access",getXmlAttr($t1, "access", "public")) unless ($t5->hasAttribute("access"));
              $node->addChild($t5);
         }
      } else {
         $node->addChild($t1->cloneNode(1));
      }
    } 

    my $bv=0;
    foreach $t1 ($node->getElementsByTagName("method")) {
        #print "method:", isVirtual($t1), ", node=", $t1->toString(1);;
        $bv=1 if (isVirtual($t1)) ;
        next if ($t1->hasAttribute("return"));
        $t4=0;
        foreach $t3 ($t1->getElementsByTagName("return")) {  $t4=1; last; } 
        $t2=trim($t1->getAttribute("name"));
        $t1->setAttribute("return","void") if ( ($t4==0) && ($t2 !~ m/^operator/i) );
    }

    if ($cls->hasAttribute("deconstructor")) {  #deconstructor; virtual if one method is virtual
        $t1=$node->ownerDocument->createElement("deconstructor");
        $t1->setAttribute("access", $cls->getAttribute("deconstructor"));
        $t1->setAttribute("virtual", $cls->getAttribute("virtualDC")) if  $cls->hasAttribute("virtualDC");
        $t1->setAttribute("virtual", "true") if ($bv);
        $node->addChild($t1);
    }

    if ($bv) {
      my $flag=0;
      foreach $t1 ($node->getElementsByTagName("deconstructor")) {
         $t1->setAttribute("virtual", "true"); $flag=1;
      }
      if ($flag==0) {
         $t1=$node->ownerDocument->createElement("deconstructor");
         $t1->setAttribute("virtual", "true"); $node->addChild($t1);
         $t1->setAttribute("impl", "");
      }
    }
    #print "$node:",$node->toString(1);
    
    foreach $t1 ($node->childNodes) {
        unless($t1->hasAttribute("access")) {
           if ( ($t1->nodeName =~ /^method$/i) || 
                ($t1->nodeName =~ /^constructor$/i) ||
                ($t1->nodeName =~ /^deconstructor$/i) ||
                ($t1->nodeName =~ /^operator$/i) 
              ) { $t1->setAttribute("access", $maccess); }
           else { $t1->setAttribute("access", $daccess); }
        }
        next unless (contains($t1->nodeName,\@CLASS_MEMBERS) );
        next unless ($t1->hasAttribute("name"));
        if (is_false($t1, "autoname") ) {
            $t1->setAttribute("realname", $t1->getAttribute("name")) ;
        } elsif ($t1->hasAttribute("access") && ($t1->getAttribute("access") eq "public") ) {
            $t1->setAttribute("realname", $t1->getAttribute("name")) ;
        } else {
            $t1->setAttribute("realname", $t1->getAttribute("name")."_") ;
        }
    }
    
    #internal class/struct
    foreach $t1 ($node->getElementsByTagName("class")) {
         $t1->setAttribute("class_prefix",$name) unless ($t1->hasAttribute("class_prefix"));
    }
    foreach $t1 ($node->getElementsByTagName("struct")) {
         $t1->setAttribute("class_prefix",$name) unless ($t1->hasAttribute("class_prefix")); 
    }
    return $node;
}

############################################################################
# generate string for parent node
#  [virtual] [modifier] clsname<templatetypes>::typedef
# <parent [access="private|..|" virtual="true|false" type="" template=""]>
#   <template />*  # templatetype node 
# </parent>
############################################################################
sub genParentsCode {
   my $node=$_[0];
   my $sp="${SP1}";  $sp = $_[1]  if ($_[1]) ;
  
   my @ha;
   push(@ha, $node->getAttribute("parents")) if ($node->hasAttribute("parents"));
   foreach my $t1 ($node->getChildrenByTagName("parent") ) {
      my $mod=getXmlAttr($t1,"access",""); $mod .= " " if ($mod);
      my $vir="";   $vir="virtual " if (xml_true($t1,"virtual"));
      my $type=getTypeStr($t1); 
      push(@ha,"${vir}${mod}${type}");
   }
  
   return ""  if (scalar(@ha)==0);
   return format_join(\@ha, ${CC_SEP}, "$sp", ": ");
}
############################################################################

############################################################################
# based on operator
sub genConstructorCodes {
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1]; my $sp=$_[2]; 
    my %codes=();  %codes=%{$_[3]} if ($_[3]);  #original source code

    my $spa="${sp}${SP1}";
    
    my $fname=$fullname[2];
    my $name=$fullname[3];
    my $sai0=$fullname[4];
    my $sci0=$fullname[5];
    
    #print "commonClass:connode=\n", $node->toString(1),"\n";
    my (@ha, @ca, @hm, @hcsa);
    
    my $scin=getInitStrs($_[1], $sp);
    my $scistr="";
    if ($scin) { 
       if (${sci0}) { $scistr = "${sci0},\n${scin}";}
       else { $scistr = "${scin}"; } 
    } elsif (${sci0}) {  $scistr=$sci0;  }

    $node->setAttribute("name", $name);
    $node->setAttribute("prefix", "${name}::");
    $node->setAttribute("return", "none");
    
    if ( $node->hasAttribute("type") && ($node->getAttribute("type") eq "self") ){
       my $arg=$node->ownerDocument->createElement("arg");
       $arg->setAttribute("name", "obj");   $arg->setAttribute("type", $name);
       $arg->setAttribute("const", "true"); $arg->setAttribute("ref", "true");
       $node->addChild($arg);
    }
    return genMethodStrs($_[0], $node, $sp, $_[3], $scistr);
}

sub genDeconstructorCodes{
    my @fullname = @{$_[0]}; # name info for class
    my $node=$_[1]; my $sp=$_[2]; 
    my $name=$fullname[3];
    $node->setAttribute("name", "~${name}");
    $node->setAttribute("prefix", "${name}::");
    $node->setAttribute("return", "none");
    return genMethodStrs($_[0],$node,$sp,$_[3],"");
}
############################################################################
############################################################################

############################################################################
# return constructor initializer strs from class node for variables
sub getInitStrs {
   my $node=$_[0];
   my $sp="";  $sp=$_[1] if ($_[1]);
   
   my ($x1, $x2);   my (@ta);
   
   push(@ta, $node->getAttribute("init")) if ($node->hasAttribute("init"));
   foreach my $t1 ($node->getChildrenByTagName("arg")) {
      next unless ($t1->hasAttribute("refname"));
      $x1=$t1->getAttribute("name");  $x2=$t1->getAttribute("refname");
      
      push(@ta, "${x2}(${x1})");
   }
   if (scalar(@ta)>0) { return format_join(\@ta,${CC_SEP},$sp, $sp); }
   else { return ""; }
}
# return constructor initializer strs from constructor node
sub getClassInitStrs {
    my $cls=$_[0];
    my $sp="";  $sp=$_[1] if ($_[1]);
   
    my ($node, $x0, $x1, $x2, $x3, $x4, $x5);
    my (@ta);
   
    #foreach my $ss ($cls->getChildrenByTagName("members")) {
    my $ss=$cls;
    foreach $node ($ss->getChildrenByTagName("var")) {
      next unless ($node->hasAttribute("default"));
      next if (xml_true($node, "static"));
      $x0=$node->getAttribute("realname");
      $x1=$node->getAttribute("default");
      
      if (xml_true($node,"string") || xml_true($node,"str")) { $x0 ="${x0}(\"${x1}\")";}
      else { if (xml_true($node,"char") || xml_true($node,"ch")) { $x0 ="${x0}('${x1}')"; }
        else {$x0 ="${x0}(${x1})";}  }
      
      push(@ta, $x0);
    }
    foreach $node ($ss->getChildrenByTagName("config")) {
      next if (xml_true($node, "static"));
      $x1 = $node->getAttribute("realname"); 
      if ($node->hasAttribute("alias") ) { $x2 = $node->getAttribute("alias");} 
      else {$x2 = $node->getAttribute("name");}; 
      $x3=$node->getAttribute("desc"); 
      
      $x0="${x1}(\"$x2\",\"$x3\"";
      if ($node->hasAttribute("default")) {
         $x1=node->getAttribute("default"); $x0 .= ",\"$x1\"";
         if ($node->hasAttribute("option")) {
            $x1=node->getAttribute("option"); $x0 .= ",$x1";
         }
      }
      $x0 .=")"; push(@ta, $x0);
    }
    
    foreach $node ($ss->getChildrenByTagName("count")) {
      next if (xml_true($node, "static"));
      $x1 = $node->getAttribute("realname"); 
      if ($node->hasAttribute("alias") ) { $x2 = $node->getAttribute("alias");} 
      else {$x2 = $node->getAttribute("name");}; 
      $x3=$node->getAttribute("desc"); 
      
      $x0="${x1}(\"$x2\",\"$x3\"";
      if ($node->hasAttribute("default")) {
         $x1=node->getAttribute("default"); $x0 .= ",\"$x1\"";
      }
      $x0 .=")"; push(@ta, $x0);   
    }
    
    foreach $node ($ss->getChildrenByTagName("profile")) {
      next if (xml_true($node, "static"));
      $x1 = $node->getAttribute("realname"); 
      if ($node->hasAttribute("alias") ) { $x2 = $node->getAttribute("alias");} 
      else {$x2 = $node->getAttribute("name");};
      $x3=$node->getAttribute("desc"); 

      $x0="${x1}(\"$x2\",\"$x3\"";
      if ($node->hasAttribute("default")) {
         $x1=node->getAttribute("default"); $x0 .= ",\"$x1\"";
      }
      $x0 .=")"; push(@ta, $x0);
    }

    return "" if (scalar(@ta)==0);
    return format_join(\@ta,${CC_SEP},${sp}, ${sp});  
}
############################################################################
############################################################################
# generate str for method node: (decl; implement; signature,inline_impl,tmplatefunc)
# <method name="" return="" ref="true|false" template="" impl="" inline="true|false"
#     static="true|false" const="true|false" virtual="true|false|pure" >
#     <template/>
#     <return/> * 
#     <arg name="" type="" const="true|false" ref="true|false" default="">
#          <type/> # template
#     </arg>
#     <impl>*
# </method>
#
#template <class T, int N> class Vector {
#  T array[N];
#  template <class F>   void  apply(F f);
#};
#template <class T, int N>
#template <class F>
#void Vector<T, N>::apply(F function)
#{
#  for (int i(0); i < N; ++i) array[i] = f(array[i]);
#}
#
# TASK: Generate code for method
#
sub genMethodStrs  {
   my @fnames=@{$_[0]};
   my $node=$_[1]; my $sp=""; $sp=$_[2] if ($_[2]); 
   my %codes=();  %codes=%{$_[3]} if ($_[3]);  #original source code
   my $initStr="";  $initStr = ":$_[4]" if ($_[4]);

   #print "*** commonClass:node=\n",$node->toString(1),"\n";
   my $implname=$fnames[1];
   my $clsname=$fnames[2];  
   $node->setAttribute("prefix", "${clsname}::");
   $node->setAttribute("pre_template", $implname) if ($implname);
   $node->setAttribute("init", $initStr) if ($initStr);
   return genFunctionCodes($node,$sp,\%codes);
}

