package CommonXml;

use strict;
use warnings;
use Exporter;

#xml modules
use XML::LibXML;

use Common qw(
      trim trimText trimNewLine splitText
      is_true is_false 
  );

our $DEBUG;

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( xmlRoot xmlFile createDoc splitXmlText
                     xml_true xml_false getList getNodeList
                     getXmlAttr copy2Attr set2Attr copyAttrsTo
                     hasNamedComponent cmpSetAttr 
                     getPkgHome getIncludeHome 
                     );

# these are exported by default.
our @EXPORT = qw( xmlRoot );

####################################################
# common-used xml subroutines
####################################################
# return the root element node from xml file
# arg1: xml file name
sub xmlRoot {
   if (-f $_[0]) { return getXmlRoot($_[0]); }
   else { createRoot($_[1]);}
}
# save xml node in a file
# arg1: xml node
# arg2: xml file name
my $XML_FORMAT=1;  #dent output
sub xmlFile {
    $_[0]->ownerDocument->toFile($_[1], $XML_FORMAT);
}
sub getDoc {
  my $parser = XML::LibXML->new();
  my $doc    = $parser->parse_file($_[0]);
  return $doc ;
}
sub getXmlRoot {
  return getDoc($_[0]) -> getDocumentElement();
}
sub createDoc {
  my $doc = XML::LibXML::Document->new("1.0");
  my $root = $doc->createElement($_[0]);
  $doc->setDocumentElement($root);
  return $doc;
}
sub createRoot {
  return createDoc($_[0]) -> getDocumentElement();
}
# arg1: xml node
# arg2: attr name
# arg3: default value
sub getXmlAttr {
   if ($_[0]->hasAttribute($_[1])) {  return $_[0]->getAttribute($_[1]); }
   if ($_[2]) { return $_[2]; }
   return "";
}
# arg1: orignal node
# arg2: destination node
# arg3: attribute name
sub copy2Attr {
   my $attr=$_[2];
   return unless ($_[0]->hasAttribute($attr));
   #return if ($_[1]->hasAttribute($attr));
   $_[1]->setAttribute($attr, $_[0]->getAttribute($attr));
}
sub set2Attr {
   my $attr=$_[2];
   return unless ($_[0]->hasAttribute($attr));
   return if ($_[1]->hasAttribute($attr));
   $_[1]->setAttribute($attr, $_[0]->getAttribute($attr));
}

sub copyAttrsTo {  # src($_[0]) to dst $_[1]
    foreach my $t1 ($_[0]->attributes()) {
      $_[1]->setAttribute($t1->nodeName, $t1->value) unless ($_[1]->hasAttribute($t1->nodeName));
    }
    return $_[1];
}

###############################################################
# return true of the attribute is "true" explicitly
sub xml_true {
   my $node = $_[0];  #xml node
   my $attr = $_[1];  #attribute name
   
   if ($node->hasAttribute($attr)) {
      return is_true(trim($node->getAttribute($attr))); 
   }
   return 0;
}
#
# return true of the attribute is "false" explicitly
sub xml_false {
   my $node = $_[0];  #xml node
   my $attr = $_[1];  #attribute name
   
   if ($node->hasAttribute($attr)) {
      return is_false(trim($node->getAttribute($attr))); 
   }
   return 0;
}
###############################################################

###############################################################^M
# get a list node from the hash:
# <pnode>
#    <$nodename name="IDREF" names="IDREFS">list-of-names(IDREFS)</$nodename>*
# </pnode>
#
# Input:
#   arg1: parent node
#   arg2: nodename of child nodes
#   arg3: attrname if provided (optional)
#   arg4: default suffix if provided (optional)
# Return: 
#   list of name: $prefix$name$suffix
###############################################################
sub getNodeList {
   my $node=$_[0];  my $name=$_[1];  my %refs; %refs=%{$_[2]} if ($_[2]); 
   
   my $t1 = getList($_[0],$_[1],"name"); my @impa;
   
   foreach my $t2 ( @{$t1} ) {
       if (exists $refs{$t2} ) {  push(@impa, $refs{$t2}); }
       else {    print " *** WARNING: missing $t2 required in ${name}\n";   }
   }
   return \@impa;
}
###############################################################
sub splitXmlText {   
   return splitText(trimNewLine($_[0]->textContent));
}
###############################################################

###############################################################
sub cmpSetAttr {
    my $target=$_[0]; my $name=$_[1]; my $src=$_[2];
    return 0 unless ($src->hasAttribute($name));
    my $srcattr=$src->getAttribute($name);
    if ($target->hasAttribute($name))
    {
       return 0 if ($target->getAttribute($name) eq $srcattr);
    }
    $target->setAttribute($name, $srcattr); return 1;
}
###############################################################

###############################################################
sub getList {
   my $node=$_[0];     my $nodename=$_[1]; 
   my $attrname=$nodename; $attrname=$_[2] if ($_[2]); 
   my $suf=""; $suf=$_[3] if ($_[3]);
   
   my (@list,$prefix,$suffix,$x0);
   my $attrnames="${attrname}s";
   
   foreach my $t1 ($node->getChildrenByTagName($nodename)) {
        $prefix=getXmlAttr($t1,"prefix",""); 
        $suffix=getXmlAttr($t1,"suffix",$suf);

        if ($t1->hasAttribute($attrname)) {
            $x0=$t1->getAttribute($attrname);
            $x0="${prefix}$x0${suffix}";   push(@list,$x0);
        }

        if ($t1->hasAttribute($attrnames)) {
           foreach $x0 (splitText($t1->getAttribute($attrnames))) {
              $x0="${prefix}$x0${suffix}"; push(@list,$x0);
           }
        }

        foreach $x0 (splitXmlText($t1)) {
            $x0="${prefix}$x0${suffix}";  push(@list,$x0);
        }
    }

    return \@list;
}

###############################################################

###############################################################
sub hasNamedComponent {
    if ($_[2]) {
        foreach my $t1 ($_[0]->getElementsByTagName($_[1])) {
            next unless ($t1->hasAttribute("name"));
            return 1 if ($t1->getAttribute("name") eq $_[2]);
        }
        return 0;
    } else {
       foreach my $t1 ($_[0]->childNodes()) {
          next if ($t1->nodeType != XML_ELEMENT_NODE);
          next unless ($t1->hasAttribute("name"));
          return 1 if ($_[1] eq $t1->getAttribute("name") );
       }
       return 0;
    }
}
####################################################
###############################################################^M
# get pkg_home from pkgname and env vars^M
###############################################################^M
sub getPkgHome {
   if (exists $ENV{"PKG_HOME"}) {  
       my $t1=$ENV{"PKG_HOME"}; 
       $t1 .= "/" unless ($t1 =~ /\/$/);
       return $t1;
   } 

   my $t1=getXmlAttr($_[0],"pkgname","");
   $t1=getXmlAttr($_[0],"pkg","") unless ($t1);
   unless ($t1) {
      print "*** WARNING: no pkgname attr for\n", $_[0]->toString(1),"\n";
      return "";
   }
   my $pkgenv=uc($t1); $pkgenv .= "_HOME";
   if (exists $ENV{$pkgenv}) {  
       my $t1=$ENV{$pkgenv}; 
       $t1 .= "/" unless ($t1 =~ /\/$/);
       return $t1;
   } else {
      print "*** ERROR: no ENV var ${pkgenv}/PKG_HOME for pkg $t1\n"; 
      exit(1); return "";
   }
}
sub getIncludeHome {
   my $t1=getPkgHome($_[0]);
   unless ($t1) { return "";}
   $t1 .="include/";
   #my $libname=getXmlAttr($_[0],"libname","");
   #unless ($libname) { 
   #   print "*** WARNING: no libname attr for\n", $_[0]->toString(1),"\n";
   #   return $t1;
   #}
   #$libname .= "/" unless ($libname =~ /\/$/);
   my $libname=getXmlAttr($_[0],"namespace","");
   if ($libname) {
      $libname =~  s/\./\//g;
      $libname .= "/" unless ($libname =~ /\/$/);
   }
   return "${t1}${libname}";
}
###############################################################
1
####################################################