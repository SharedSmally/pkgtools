#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x3;

my $dir = getcwd;
my $sdir = dirname(dirname($0)); #script homedir

use Common qw( trim writeFile readFile writeArray info);  # import listed items
use CommonXml qw(xmlRoot xmlFile splitXmlText getXmlAttr copy2Attr );
use CommonMD5 qw(parseLabelFiles);
use JavaClass qw(getJavaClassCode getJavaImportCode );

#use XML::LibXML;
use XML::LibXML qw(XML_ELEMENT_NODE);

# java jar node: namespace/package
# <jar basespace="xxx">
#   <jmod subspace>list-of-jmod</jmod>* : ${basespace}.${subspace}.${jmod}
# </jar>
#
#
# <jmod namespace="aaa.bbb.ccc" scope="">
#   <import></import>*
#   <class> list of java classes </cfile>*
#   <interface> list of java interfces </interface>*
# </jmod>
# java class/inteface
#  
# <interface> similar to class
# //annotation
# <class name="" parent="" interfaces="" main="true|false" scope="" 
#    modifier="abstract|final" static="true|false">
#   <template name="T" ext=""/>
#   <interface scope="">interfaces</>
#   <import pkg="">imported-</import>*
#   <constructor>
#   <method return="" scope="" static="true|false" abstract="true|false" throws="">
#      <throw>list-throws</throw>
#      <arg name="" type="" default=""/>*
#   <method>
#   <var name="" type="" scope="public|protected|private|package"
#         transient="true|false" volatile="true|false" default="def-value"
#         static="true|false" access="r|w|rw" template="true|false" ext="" array=""/>
#   <vars type="" scope="public|protected|private|package" 
#         static="true|false" access="r|w|rw" > var-list</vars>
#   <const name="" type="" scope="public|protected|private|package" 
#         static="true|false" access="r|w|rw" value=""/>
#   <group>
#       <constructor/>
#       <method/>
#       <var>
#       <const>
#   <group>
#   <inclass name="">
#   </inclass>
# </class>
#
#
sub updateJavaFile {
    my ( $nodename, $fname, $name, $ns) = @_;
    
    # parse existing code from *.java 
    my @labelFiles=("${name}.java",);
    my %implCodes = %{parseLabelFiles( (\@labelFiles) )}; 
   
    print "   *** update java based on $fname\n";  
    my $root= xmlRoot($fname, $nodename);
    
    my $pkg=""; $pkg="package ${ns};\n" if ($ns);
    
    my $impts = join("\n", @{getJavaImportCode ($root)} );
    
    my $codes = join("\n", @{getJavaClassCode ($root,\%implCodes) });
    
    writeFile("${name}.java", "${pkg}\n${impts}\n${codes}\n"); 
}
 
sub createJavaMetaXml{
    my ( $nodename, $fname, $name, $ns) = @_;
    print "   *** create meta $fname\n";
    
    my $root= xmlRoot($fname, $nodename);
    $root->setAttribute("name", $name);
    
    my $con=$root->getOwner()->createElement("constructor");
    my $arg1=$root->getOwner()->createElement("arg");
    $arg1->setAttribute("name", "name");
    $arg1->setAttribute("type", "int");
    $con->addChild($arg1);
    $root->addChild($con);
    
    xmlFile($root, $fname); 
} 
sub updateJmod{
    my $mfile=$_[0];
    my $node=xmlRoot($mfile); 	
 
    my $ns=getXmlAttr($node,"namespace","");
    $ns=getXmlAttr($node,"package","") unless ($ns);

    system("mkdir -p ./meta") unless (-d "./meta");

    my ($t0, $t1, $t2, $fname);
    
    foreach $t0 ("class", "interface") {
        foreach $t1 ($node->getChildrenByTagName($t0)) {
            foreach $t2 (splitXmlText($t1)) {
                $t2=trim($t2); next unless ($t2);
                $fname = "meta/${t2}.xml"; 
                
                if (-f ${fname}) { updateJavaFile($t0, $fname, $t2, $ns); 
                } else {  createJavaMetaXml($t0, $fname, $t2, $ns); }
            }
        }
    }
}

# <jmod namespace="xxx">
#   <interface>list-of-class</interface>
#   <class>list-of-class</class>
# </jmod>
#
sub createJmodMetaXml{
    my $name = $_[0];
    my $dname=$name;
    $dname =~ s/\./\//g;
    $dname .= "/meta";
    system("mkdir -p ${dname}") unless (-d $dname);
    
    my $fname="${dname}/jmod.xml";

    if (-f $fname) { print "   *** existing jmod $fname: no updating\n";  return; };

    my $root= xmlRoot($fname, "jmod");
    $root->setAttribute("namespace", $name);

    my $cls=$root->getOwner()->createElement("class");
    $cls->appendTextNode(" ");
    $root->addChild($cls);

    my $intf=$root->getOwner()->createElement("interface");
    $intf->appendTextNode(" ");
    $root->addChild($intf);    

    print "   *** update jmod $fname\n"; xmlFile($root, $fname); 
} 


sub updateJAR {
    my $xfile=$_[0];
    my $node=xmlRoot($xfile); 
    my $bs=getXmlAttr($node,"base","");
    $bs=getXmlAttr($node,"basespace","") unless ($bs);
    $bs .= "." if ($bs);

    my ($t0, $t1, $t2, $ns, $fname);
    
    foreach $t0 ("jmod",) {
        foreach $t1 ($node->getChildrenByTagName($t0)) {
            my $mybs = getXmlAttr($t1,"subspace","");
            $mybs .= "." if ($mybs);
            foreach $t2 (splitXmlText($t1)) {
                $t2=trim($t2); next unless ($t2);
                $ns = $bs; $ns .= "${mybs}${t2}"; 
                createJmodMetaXml( $ns) ;
            }
        }
    }
}
###########################################################################
print "[start script]: $0\n";

my $xfile="./jar.xml";
my $mfile="./meta/jmod.xml";
if (-f $xfile) {
    info("update java jar based on $xfile");
    updateJAR($xfile);
} elsif (-f $mfile) {
    info("update java jmod based on $mfile");
    updateJmod($mfile);
} else {
    print ("  no ${xfile} or $mfile exits\n"); 
}

print "[end script]: $0\n";
###########################################################################
