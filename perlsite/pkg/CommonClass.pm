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
              is_true is_false format_join splitText);
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
sub setIfNot {
	my ($node,$name,$val)=@_;
	$node->setAttribute($name,$val) unless ($node->hasAttribute($name));
}
# return trur if the given node attribute is None
sub isNone {
	my ($node, $name)=@_;
	return 0 unless $node->hasAttribute($name);
	return $node->getAttribute($name) =~ m/^none$/i;
}
#genFuncDefCode($t2, $SP1) {
sub genFuncDefCode{
 	my ($node,$s0)=@_; 	
 	$s0="" unless ($s0);
 	if (xml_true($node,"extc")) {
 		$s0 .= "extern \"C\" { typedef "; $s0 .= $node->textContent; $s0 .= ";}";
	} else {
		$s0 .= "typedef "; $s0 .= $node->textContent; $s0 .=";" 
	}
	return $s0;
 }
############################################################################
# Simple Interfaces
############################################################################

############################################################################
# <class name="" copy|default|assign|deconstructor="" parent="" in|output="" operators="">
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
#
# template <templates>
# class name<templates, partialtemplatetypes> 
#  : parents
# {
#   friend classes|structs|functions;
#   using [namespace] class;
#
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
# };
#
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
  #print "expanded class:\n", $cnode->toString(1), "\n";
  #print "original class:\n", $cls->toString(1), "\n";
  
  ######################################### 
  my ($t1,$t2,$t3, $x0, $x1,$x2,$x3,$x4,$x5);
  
  #############################################################
  #template info: 
  # st0: template <typename T1, ..., typename Tn=default>
  # st1: template <typename T1, ..., typename Tn>
  # st2: <T1, ..., Tn> # real templates
  # st3: <P1,..., Pm>  # partial parameterized
  # st4: <T1,...,Tn,P1,...,Pm>
  # st5: number of real templates: 
  my ($st0,$st1,$st2,$st3,$st4,$st5) = getTemplateTypeStrs($cls);
  push(@ha,$st0) if ($st0);     ###  template decl
  #print "CommonClass:st0-4:\n${st0}\n${st1}\n${st2}\n${st3}\n${st4}\n";
  ######################################### templatetype info;
  my $name = $cls->getAttribute("name");
  # for internal classes: xxx::class
  my $prename=getXmlAttr($cls, "prefix",""); $prename .="::" if ($prename); 
  my $clsname="${prename}${name}${st4}";
  
  my $mod="class";  $mod="struct" if ( xml_true($cls, "struct") );
  if ($st3) { push(@ha, "${mod} ${name} $st4 "); }  ###  class decl
  else { push(@ha, "${mod} ${name} "); } 
  
  ##############################################
  my $haparent = genParentsCode($cnode);
  push(@ha,$haparent) if ($haparent);   ###  parent decl
  ##############################################

  ##############################################
  push(@ha, "{");   # start class
  ##############################################
  ########## friend & using
  foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      if ($t1->nodeName eq "using") { push(@ha, genClassUsingCode($t1, $SP1)); next; }
      if ($t1->nodeName eq "friend") {push(@ha, @{genFriendDefCode($t1, $SP1)}); next;}
  }

  ## friend functions for iput/output
  if (xml_true($cls,"input")) {
    $x0 = "friend std::istream & operator>>(std::istream & in, ${name} & obj)\n{"; push(@ha, $x0);
    $x0="${SP1}obj.input(in);\n${SP1}return in;\n}"; push(@ha, $x0);
  }
  if (xml_true($cls,"output")) {
    $x0 = "friend std::ostream & operator<<(std::ostream & out, const ${name} & obj)\n{"; push(@ha, $x0);
    $x0="${SP1}obj.output(out);\n${SP1}return out;\n}"; push(@ha, $x0);
  }
  ####  insert methods from attribute: default/copy/assign constructor, deconstructor; input/output stream 
 
  # variables for copy, assign, read/write(io), compare, xml, jason; 
  # initial string of variables for constructors.  
  my $initHaStr=getClassInitStrs($cnode, ${SP2});
  my $initCaStr=getClassInitStrs($cnode, ${SP1});
      
  ######################################### typedef & enum & decl & using
  my $flag=0;  
  my @CLASS_PREDEFINE=("using","friend");
  my @CLASS_FIELDS=("const","vars","var","count","config","profile","metric");
  
  my @fullname=($st0, $st1, $clsname, $name, $initHaStr, $initCaStr); 
    
  my $sp=$SP1; my $pre="";
  #class methods and class/struct    
  foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      my $access=$t1->nodeName;
      next if (contains($access, \@CLASS_PREDEFINE));
      $flag=1;
       
	  foreach $t2 ($t1->childNodes) {
    	  next if ($t2->nodeType != XML_ELEMENT_NODE);
    	  my $nodename = $t2->nodeName;
    	  next if ( contains($nodename, \@CLASS_FIELDS) );
    	      	  		  
		  if ($flag) { push(@ha,"${access}:"); $flag=0; }  
		  		  		  
		  if ( ($nodename eq "class") || ($nodename eq "struct")) {
		  	  setIfNot($t2, "class_prefix", $clsname);   # internal class/struct
        	  ($x0, $x1, $x2) = genClassCode($t2, $codes, $_[2]); # \%mcodes) ;
              push(@ha, @{$x0}); $flag=1;
              if ($st1) { push(@ham,  @{$x1}) if (@{$x1}); }
              else {  push(@ca,  @{$x1}) if (@{$x1}); }
              push(@ham,  @{$x2}) if (@{$x2});
              next;
	  	  }
	  	  
		  if ( $nodename eq "typedef") {  push(@ha, genTypeDefCode($t2, $SP1)); next; }
		  if ( $nodename eq "funcdef") {  push(@ha, genFuncDefCode($t2, $SP1)); next; }
		  if ( $nodename eq "enum")    {  push(@ha, genEnumCode($t2, $SP1)); next; }
		  
		  copyAttrsTo($t1, $t2); #
		  	  	  		
	  	  ## For all methods: return="none" for constructor/deconstructor;
	  	  if ($nodename eq "constructor") {
	  	  	  ($x0, $x1, $x2, $x3, $x4, $x5) = genConstructorCodes(\@fullname, $t2, ${SP1}, $codes); # \%mcodes) ;
	  	  } elsif ($nodename eq "deconstructor") {
	  	  	  ($x0, $x1, $x2, $x3, $x4, $x5) = genDeconstructorCodes(\@fullname, $t2, $SP1, $codes); # \%mcodes);
	  	  } elsif ($nodename eq "method") {
	  	  	  ($x0, $x1, $x2, $x3, $x4, $x5) = genMethodStrs(\@fullname, $t2, $SP1, $codes); #\%mcodes) ;
	  	  } elsif ($nodename eq "operator") {
	  	  	  ($x0, $x1, $x2, $x3, $x4, $x5) = getOperatorCodes(\@fullname, $t2, $SP1, $codes); # \%mcodes) ;
	  	  } elsif ($nodename eq "cast") {
	  	  	  ($x0, $x1, $x2, $x3, $x4) = genCastCodes(\@fullname, $t2, $SP1, $codes);# \%mcodes) ;
 	  	  } elsif ($nodename eq "union") {
	  	  	  $x0=genUnionCode($t2,$SP1); $x1=$x2=$x3=$x4=$x5=""; 
	  	  } else {
	  	  	  print "unknown node:",$nodename; next;
	  	  }
	  	  #print "node:",$t2->toString(1),"\n";
	  	  #print "x1=${x1}\n";
	  	  	  	  
	  	  $x0 .= ";\n";  push(@ha, $x0); 
          if ($st1) { push(@ham,  $x1) if ($x1); }
          else {  push(@ca,  $x1) if ($x1); }
          push(@ham,  $x4) if ($x4);         	  	  
	  }      
  }
  
  ## variables section  
  my (@fha,@fpa); my $faflag=1;
  foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      my $access=$t1->nodeName; $flag=1;
      next if (contains($access, \@CLASS_PREDEFINE));
      
	  foreach $t2 ($t1->childNodes) {  # public|protected|private
    	  next if ($t2->nodeType != XML_ELEMENT_NODE);    	  
		  my $nodename = $t2->nodeName;
		  
		  if ( contains( $nodename, \@CLASS_FIELDS) ) { # class fields
		  	  if ($flag) { push(@fha,"${access}:"); $flag=0; }
		  	  if ($faflag) { push(@fpa,"public:"); $faflag=0; }
		  
		      ($x1,$x2) = getMemberDeclStr(\@fullname, $t2, $SP1);		      
              push(@fha, $x1) if ($x1);  push(@ca, $x2) if ($x2);
              
              # variable access methods
              if ( ($access =~ m/^protected$/i) || ($access =~ m/^private$/i)) {
        	  	($x0,$x1,$x2)= getVarAccessCodes(\@fullname, $t2, $SP1);
           	  	push(@fpa, @{$x0}) if ($x0 && @{$x0}); 
           	  	push(@ca, @{$x1}) if ($x1 && @{$x1});
              } 
		  }
	  }      
  } 
  
  if (scalar(@fpa)>1) { push(@ha, @fpa); }
  
  # fields access methods
  if (@fha) { push(@ha, @fha); }
  
  # none constructors or deconstructors
  # http://www.cplusplus.com/reference/new/operator%20new/
  # throwing (1) void* operator new (std::size_t size) throw (std::bad_alloc);
  # nothrow (2) void* operator new (std::size_t size, const std::nothrow_t& nothrow_value) throw();
  # placement (3) void* operator new (std::size_t size, void* ptr) throw();
  #
  my @noneha;
  if ( isNone($cnode,"default") ) { push(@noneha, "${SP1}${name}();");}
  if ( isNone($cnode,"copy"   ) ) { push(@noneha, "${SP1}${name}(const ${name} &);"); }
  if ( isNone($cnode,"assign" ) ) { push(@noneha, "${SP1}${name} & operator=(const ${name} &);"); }
  if ( isNone($cnode,"deconstructor") ) { push(@noneha, "${SP1}~${name}();"); }
  if ( isNone($cnode,"new" ) )    { push(@noneha, "${SP1}void* operator new (std::size_t size) throw (std::bad_alloc);"); }
  if ( isNone($cnode,"news" ) )   { push(@noneha, "${SP1}void* operator new[] (std::size_t size) throw (std::bad_alloc);"); }
  if ( isNone($cnode,"delete" ) ) { push(@noneha, "${SP1}void operator delete (void* ptr) throw();"); }
  if ( isNone($cnode,"deletes") ) { push(@noneha, "${SP1}void operator delete[] (void* ptr) throw();"); }
  if (@noneha) { push(@ha, "\nprivate:");  push(@ha, @noneha); }
       
  ############################################################################
  ###########  extra signature for class.
  if (xml_true($cls,"ext") || xml_true($cls, "extension") ) {
     push(@ha,getLabelStr("${name}$st1", $codes));
  }
  
  ##############################################
  $x1="};\n"; push(@ha, $x1);  # end of class

  return(\@ha, \@ca, \@ham);    
}
############################################################################
# 
# Input:
#   arg1: classNode
#   arg2: interface map: name->interface
# Output:
#   classnode with expensions
#
my @ACCESSES=("public","protected","private");
my @CLASS_MEMBERS=("const","var","count","config","profile");
sub getAccess {
	my ($node, $name)=@_;
	
	return "" unless ($node->hasAttribute($name));
	my $myname=$node->getAttribute($name);
	return $myname if (contains($myname,\@ACCESSES));
	return "";
}
sub provisionInterface {
    my $node=$_[0]; my %ifs = %{$_[1]}; my $names=$_[2];
    my ($t2,$t3,$t4,$t5);
    
    my $access="public";
	my $ifnode=$node->ownerDocument->createElement($access);			
    foreach $t2 (splitText($names)) {
          if (!exists $ifs{$t2}) { print "*** WARNING: interface $t2 not exists\n"; next; }            
          foreach $t3 (@{$ifs{$t2}}) {
             foreach $t4 ($t3->getChildrenByTagName("method")) {
                 $t5=$t4->cloneNode(1); 
                 setIfNot($t5,"virtual","pure");
                 $ifnode->addChild($t5);
              }
          }
          $t3=$node->ownerDocument->createElement("parent");
          $t3->setAttribute("virtual","true"); 
          $t3->setAttribute("access",$access);            
          $t3->setAttribute("type",$t2); $node->addChild($t3);	
    }	
    $node->addChild($ifnode);   	
}

##########################################################
sub expandClass { # only for members; and constructors
    my $cls=$_[0]; 
    my %ifs; %ifs=%{$_[1]} if ($_[1]);               
    
    my $node = copyAttrsTo($cls, $cls->cloneNode(0));
    
    #for level1 methods
    my $access=getXmlAttr($cls,"access","public");
    my ($t0,$t1, $t2, $t3, $t4, $t5);
    
    if ($cls->nodeName eq "interface") {  #deconstructor; virtual if one method is virtual
        my $ifnode = $node->ownerDocument->createElement($access);
        unless ($cls->hasAttribute("deconstructor")) {
        	$t1=$node->ownerDocument->createElement("deconstructor");
        	$t1->setAttribute("virtual", "true");
        	$t1->setAttribute("impl", "");
        	$ifnode->addChild($t1);
        }
    	foreach $t1 ($cls->getChildrenByTagName("method")) {
    		setIfNot($t1,"virtual","pure");
    		$ifnode->addChild($t1);
    	}
    	$node->addChild($ifnode);
    }
                
    my %methods;
    foreach $access (@ACCESSES) { $methods{$access} = $node->ownerDocument->createElement($access);}
    
    my $name=$node->getAttribute("name");
    $access=getAccess($cls,"default");
    if ($access) {  # default constructor
        $t1=$node->ownerDocument->createElement("constructor");
        $methods{$access}->addChild($t1);
    }
    
    $access=getAccess($cls,"copy");
    if ($access) {     # copy constructor
        $t1=$node->ownerDocument->createElement("constructor");
        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("name", "obj");   $t2->setAttribute("type", $name);
        $t2->setAttribute("const", "true"); $t2->setAttribute("ref", "true");
        $t1->addChild($t2);
        $methods{$access}->addChild($t1);
    }
        
    $access=getAccess($cls,"assign");
    if ($access) {   # assign operator
        $t1=$node->ownerDocument->createElement("method");
        $t1->setAttribute("name", "operator=");        
        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("name", "obj");   $t2->setAttribute("type", $name);
        $t2->setAttribute("const", "true"); $t2->setAttribute("ref", "true");

        $t3=$node->ownerDocument->createElement("return");
        $t3->setAttribute("class", $name);   $t3->setAttribute("ref", "true");

        $t1->addChild($t2); $t1->addChild($t3); 
        $methods{$access}->addChild($t1);
    }
    $access=getAccess($cls,"new");
    if ($access) {     # void* operator new (std::size_t size) throw (std::bad_alloc);
        $t1=$node->ownerDocument->createElement("operator");
        $t1->setAttribute("name","new");
        $t1->setAttribute("arg","std::size_t size");
        $t1->setAttribute("return","void *");
        $t1->setAttribute("throw","std::bad_alloc");
        $methods{$access}->addChild($t1);
    }
    $access=getAccess($cls,"news");
    if ($access) {     # void* operator new[] (std::size_t size) throw (std::bad_alloc);
        $t1=$node->ownerDocument->createElement("operator");
        $t1->setAttribute("name","new[]");
        $t1->setAttribute("arg","std::size_t size");
        $t1->setAttribute("return","void *");
        $t1->setAttribute("throw","std::bad_alloc");
        $methods{$access}->addChild($t1);
    }
    $access=getAccess($cls,"delete");
    if ($access) {     # void operator delete (void* ptr) throw();
        $t1=$node->ownerDocument->createElement("operator");
        $t1->setAttribute("name","delete");
        $t1->setAttribute("arg","void * ptr");
        $t1->setAttribute("throw","");
        $methods{$access}->addChild($t1);
    }
    $access=getAccess($cls,"deletes");
    if ($access) {     #  void operator delete[] (void* ptr) throw();
        $t1=$node->ownerDocument->createElement("operator");
        $t1->setAttribute("name","delete[]");
        $t1->setAttribute("arg","void * ptr");
        $t1->setAttribute("throw","");
        $methods{$access}->addChild($t1);
    }
            
	$access=getAccess($cls,"input");
    if ($access) {
        $t1=$node->ownerDocument->createElement("method");
        $t1->setAttribute("name", "input");
        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("type", "std::istream");   $t2->setAttribute("ref", "true");
        $t2->setAttribute("name", "in");   $t1->addChild($t2); 
        $methods{$access}->addChild($t1);
    }
    $access=getAccess($cls,"output");
    if ($access) {
        $t1=$node->ownerDocument->createElement("method");
        $t1->setAttribute("name", "output"); $t1->setAttribute("const", "true");
        $t2=$node->ownerDocument->createElement("arg");
        $t2->setAttribute("type", "std::ostream");   $t2->setAttribute("ref", "true");
        $t2->setAttribute("name", "out");   $t1->addChild($t2); 
        $methods{$access}->addChild($t1);
    }
	###### Additional methods from attrs
	while ( my ($key, $value) = each %methods )	{$node->addChild($value);}

    # implement interfaces
    if ($cls->hasAttribute("impl")) {
        provisionInterface($node,$_[1],$cls->getAttribute("impl"));
    }

	foreach $t1 ($cls->getChildrenByTagName("interface")) {
		provisionInterface($node,$_[1],$t1->textContent);
	}
    
    ###################### variable access methods(only for protected and private)
    
    foreach $t1 (@{$cls->childNodes}) {  
      next if ($t1->nodeType != XML_ELEMENT_NODE);
      my $nodename=$t1->nodeName;
      next if ( ($cls->nodeName eq "interface") && ($nodename eq "method"));
      #print "CommonClass::nodename=${nodename}\n";      
      $node->addChild($t1->cloneNode(1));     
    }
        
    foreach $t1 ($node->childNodes) {        
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
   push(@ha, $node->getAttribute("parent")) if ($node->hasAttribute("parent"));
   push(@ha, $node->getAttribute("parents")) if ($node->hasAttribute("parents"));
   foreach my $t1 ($node->getChildrenByTagName("parent") ) {
      my $mod=getXmlAttr($t1,"access",""); $mod .= " " if ($mod);
      my $vir="";   $vir="virtual " if (xml_true($t1,"virtual"));
      $vir="public ${vir}" if (xml_true($t1,"public"));
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

