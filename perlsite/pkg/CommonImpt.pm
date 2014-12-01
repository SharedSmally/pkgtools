package CommonImpt;

use strict;
use warnings;
use Exporter;
use XML::LibXML;

use Common qw( trim splitText getUnique
    getDirStr getFileSuffixStr getNS_underscore
);
use CommonXml qw( 
    xmlRoot xmlFile createDoc 
    getXmlAttr copyAttrsTo xml_true
    splitXmlText
 );
 
use XML::LibXML qw(XML_ELEMENT_NODE);

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( 
     getImports getCFileImportStr getHFileImportStr getCImportStr
 );

# these are exported by default.
our @EXPORT = qw( getImports );
my $DEBUG=0;
############################################################################
# package repository
############################################################################
# <repository>
#   <package name="pkgname" version="major.minor.revision"
#      home="homepath" system="true|false" redefine="false|true" 
#      namespace="ns1::ns2" prefix="" suffix="">
#     <module name="modname" libs="" libpath="" incpaths=""  
#        system="true|false" redefine="false|true" 
#        namespace="ns1::ns2" prefix="" suffix=""/>*
#   <package>
# <repository>
############################################################################
############################################################################
sub getImports {
    my $node=$_[0]; #getRoot($_[0]);
     
    my (@imptfiles,%impts);
    push(@imptfiles,"meta/import_pkg.xml"); #package import
    push(@imptfiles,"meta/import_std.xml"); #standard import

    foreach my $t1 ($node->getChildrenByTagName("import")) {
       push(@imptfiles,$t1->getAttribute("target"));
    }
    my $t2 = getUnique(\@imptfiles);
    foreach my $t3 (@{$t2}) {
        next unless (-f $t3);
        print "    read import from ${t3}\n";
        my $myimpts =  readImportFromFile($t3);
        while ( my ($key, $value) = each( %{$myimpts} ) ){
            if (exists $impts{$key}) { 
               print "***WARNING: import name=$key from $t2 already exists.\n"; 
            } else {  $impts{$key}=$value; }
        }
    }
    return \%impts;
}
###########################################################################
###########################################################################
sub readImportFromFile {
   my $root=xmlRoot($_[0]);
   my (%impts, $name);

   my $pkgname=getXmlAttr($root,"name","");
   $pkgname .= "::" if ($pkgname);
   #print "node:", $pkgname;
   
   foreach my $t1 ($root->childNodes){ 
     next if ($t1->nodeType != XML_ELEMENT_NODE);
     $name=$pkgname;
     if ($t1->nodeName eq "module") {
     	 $name .= $t1->getAttribute("name");
         if (exists $impts{$name}) { 
            print "*** WARNING: import module name=$name from $_[0] already exists.\n"; 
         } else {  $t1=copyAttrsTo($root, $t1); $impts{$name}=$t1; }
     } elsif ($t1->nodeName eq "library") {
     	 $name .= $t1->getAttribute("libname");
         if (exists $impts{$name}) { 
            print "*** WARNING: import library name=$name from $_[0] already exists.\n"; 
         } else {  $t1=copyAttrsTo($root, $t1); $impts{$name}=$t1; }     
     } else {
         $name = $t1->getAttribute("name");     	
         foreach my $t2 ($t1->getChildrenByTagName("module")){
         	my $t3=copyAttrsTo($t1, $t2->cloneNode(1));
         	my $t4=$t2->getAttribute("name");  $t4="${name}::${t4}";
         	if (exists $impts{$t4}) { 
            	print "*** WARNING: import name=$t4 from $_[0] already exists.\n"; 
         	} else {  $impts{$t4}=$t3; }
       	}       
     }
   }

   if ($DEBUG) {
       while ( my ($key, $value) = each( %{impts} ) ){
           print "import[$key]=\n",$value->toString(1),"\n\n";
       }
   }
   return \%impts;    
}

############################################################################
# generate source code based on xxx.xml: xxx=library;module;xsg;...
# module is part of the library, it includes a list of classes under 
#   the same directory. The source code can be redefined in meta/class.xml.
#
# <library namespace="" subdir="">
#    <import package="pkgname" modules="module1,module2" 
#            version="major.minor.revision" target=""/>
#    <flag value="" values=""/>*  
#    <flags target="" append="true|false" prefix="" suffix="" local="true|false">
#            lisf-of-flags</flags>* 
#       #ex.CXXFLAGS += -Dxxx[=yyy]: target="CXXFLAGS" append="true" prefix="-D"
# 
#    <class> list of classes </cfile>*  each has its own *.cc and *.h
#    <class file=""> list of classes </cfile>: share the same *.cc and *.h
#    <interface> list of classes </cfile>*  each has its own *.cc and *.h
#    <interface file=""> list of classes </cfile>: share the same *.cc and *.h
# </library> 
############################################################################
############################################################################
# generate the header_files_string for header/*.cc file
# <cfile himport="" cimport="">
#    <h></h>*
#    <himport></himport>*
#    <c></c>*
#    <cimport></cimport>*
# <cfile>
############################################################################
#arg1: node
#arg2: impts mapping
sub getHFileImportStr {
    my $node=$_[0]; my %impts=%{$_[1]}; my $imptname=$_[2];
    
    #print "Himport:node=", $node->toString(1),"\n";
    my @impa; my $pkgname=getXmlAttr($node,"pkgname",""); 
    my $modname=getXmlAttr($node,"modname","");
    $imptname .= "_${modname}" if ($modname);   
    
    #foreach my $t1 ($node->getChildrenByTagName("himport") ) {
    foreach my $t1 ($node->childNodes) { 
        next if ($t1->nodeType != XML_ELEMENT_NODE);
        next if ( ($t1->nodeName ne "h") && ($t1->nodeName ne "himport") );
        	
        my $name = getXmlAttr($t1,"use",$imptname);
        $name = getXmlAttr($t1,"using",$name);
        
        unless (exists $impts{$name}) {
            $name="${pkgname}::${name}" if ($pkgname);
        }
        if (exists $impts{$name}) { 
            foreach my $t2 (splitXmlText($t1)) {
                push(@impa, getHImportStr($t2, $impts{$name}) );
            }
        } else { 
            print "*** WARNING: Not found imports for $name in h files.\n"; 
        }
    }
    return join("\n",@impa);
}

sub getCFileImportStr {
    my $node=$_[0]; my %impts=%{$_[1]}; my $imptname=$_[2];
    #print "node:", $node->toString(1),"\n", "; $imptname\n";
    #print "impt:${imptname}\n";
    
    my @impa; my $name; 
    my $modname=getXmlAttr($node,"modname",""); 
    $imptname .= "_${modname}" if ($modname);
    
    my $pkgname=getXmlAttr($node,"pkgname", "");
    
    #foreach my $t1 ($node->getChildrenByTagName("cimport") ) {
    foreach my $t1 ($node->childNodes) { 
        next if ($t1->nodeType != XML_ELEMENT_NODE);
        next if ( ($t1->nodeName ne "c") && ($t1->nodeName ne "cimport") );
            	
        $name = getXmlAttr($t1,"use",$imptname);
        $name = getXmlAttr($t1,"using",$name);
        
        unless (exists $impts{$name}) {
            $name="${pkgname}::${name}" if ($pkgname);
        }
        
        if (exists $impts{$name}) { 
            foreach my $t2 (splitXmlText($t1)) {
                push(@impa, getCImportStr($t2, $impts{$name}) );
            }
        } else {  
            print "*** WARNING: Not found imports for $name in cxx files.\n"; 
        }
    }  
    
    #self
    $name=getXmlAttr($node,"name", "");        
    my $cname=${imptname};
    
    unless (exists $impts{$cname}) {
       $cname="${pkgname}::${cname}" if ($pkgname);
    }
        
    if (exists $impts{$cname}) { 
       push(@impa, getCImportStr($name, $impts{$cname}) );
    } else {  
            print "*** WARNING: Not found imports for $cname in cxx files.\n"; 
    }    
                
    return join("\n",@impa);
}

############################################################################
# return the import strings for xml import node
# <import name="name" prefix="dir" suffix=".h" local="true|false" 
#     redefine="true|false" namespace="nameapce">headers</import>
# generated code in *.h (header=true) or source code (header=false): 
#   #ifdef  ${namespace_}${prefix_}header${_suffix}
#   #define ${namespace_}${prefix_}header${_suffix}  (if #redefine exists)
#   #include <${prefix/}header${.suffix}>
#   #endif
############################################################################
sub getHImportStr {
  my ($x1,$node) = @_;  #head_name and xml import node
  
  my $p0=getXmlAttr($node,"prefix","");  $p0=getDirStr($p0) if ($p0);

  my $s0=getXmlAttr($node,"suffix","");  $s0=getFileSuffixStr($s0) if ($s0);  
  my $s1=$s0; if (length($s1)>0) { $s1 =~ s/\./\_/g; }
 
  my $ns=getXmlAttr($node,"namespace",""); $ns=getNS_underscore($ns) if ($ns); 
     
  # import bracket: default="";
  my $b0="<"; my $b1=">";
  if (xml_true($node,"local")) { $b0="\""; $b1="\"";}
  
  my @ha;
  my ($x2,$x3,$x4);
  my $redefine=xml_true($node, "redefine");  
  
  $x1=trim($x1); $x4=$x1; $x4 =~ s/\//\_/g; $x4 =~ s/\./\_/g; next if (length($x1)==0);
  $x2="${ns}${x1}${s1}";  $x4="${ns}${x4}${s1}"; 
  $x3="#ifndef ${x4}";  push(@ha, $x3);
  if ($redefine) {  $x3="#define ${x4}"; push(@ha, $x3); }
  $x3="#include ${b0}${p0}${x1}${s0}${b1}"; push(@ha, $x3);
  $x3="#endif\n"; push(@ha, $x3);

  return join("\n", @ha);
}

sub getCImportStr {
   my ($x1,$node) = @_;  #head_name and xml import node
  
  my $p0=getXmlAttr($node,"prefix","");  $p0=getDirStr($p0) if ($p0);

  my $s0=getXmlAttr($node,"suffix","");  $s0=getFileSuffixStr($s0) if ($s0);  
  my $s1=$s0; if (length($s1)>0) { $s1 =~ s/\./\_/g; }
 
  my $ns=getXmlAttr($node,"namespace",""); $ns=getNS_underscore($ns) if ($ns); 
     
  # import bracket: default="";
  my $b0="<"; my $b1=">";
  if (xml_true($node,"local")) { $b0="\""; $b1="\"";}
  
  my @ha;  my ($x2,$x3,$x4);
  
  $x1=trim($x1); $x4=$x1; $x4 =~ s/\//\_/g; $x4 =~ s/\./\_/g; next if (length($x1)==0);
  $x3="#include ${b0}${p0}${x1}${s0}${b1}"; push(@ha, $x3);
 
  return join("\n", @ha);
}
############################################################################


1
############################################################################
