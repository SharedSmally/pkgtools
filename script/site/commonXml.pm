#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonXml;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(
          isXmlFalse isXmlTrue getXmlNS  getXmlFileName         
          getXmlTextArray copyTemplateXml hasChild addNodeText
          getXmlIncStrs getXmlSrcStrs  getXmlNSStrs 
          getXmlAttr readXmlRoot getXmlRoot writeXml readXmlDoc 
          hasNamedComponent  splitXmlText xmlFile createDoc           
          getHFileIncs getCFileIncs
          getPkgHome getIncludeHome 
          ) ;

use common;
###########################################
# input: $xnode; $name
sub isXmlTrue {
	my ($node, $attr)=@_;
	#return 1 if (!$node->hasAttribute($attr));
	return 0 if (!$node->hasAttribute($attr));
	return isTrue($node->getAttribute($attr));	
}
# input: $xnode; $name
sub isXmlFalse {
	my ($node, $attr)=@_;
	#return 1 if (!$node->hasAttribute($attr));
	return 0 if (!$node->hasAttribute($attr));
	return isFalse($node->getAttribute($attr));		
}
# input: xnode
sub getXmlAttr {
	my ($node, $attr)=@_;	
	my $val = (@_>=3) ? $_[2] : "";
	return ($node->hasAttribute($attr)) ?  $node->getAttribute($attr) : $val;		
}
sub getXmlText {
	return $_[0]->textContent;			
}
# return: text array from text node
sub getXmlTextArray {	
	#return arrayNormStr($_[0]->textContent);
	my @a1 = arrayNormStr($_[0]->textContent);
	return \@a1;
} 
######################################
#get namespace from namespace attr: 
sub getXmlNS {
	my $s0 = getXmlAttr($_[0],"namespace","");
	$s0 = getXmlAttr($_[0],"ns","") if (length($s0)==0);	
	return $s0;			
}

sub getXmlFileName {
	my $s0 = getXmlAttr($_[0],"name","");
	$s0 = getXmlAttr($_[0],"file","") if (length($s0)==0);	
	$s0 = getXmlAttr($_[0],"filename","") if (length($s0)==0);
	return $s0;				
}
##################################
#input: xml node with <inc system="true|false" 
#    redefine="true|false" namespace="" prefix="" suffix="">headers</inc>
# return array:
# #ifndef ${ns}_${pref}${name}${suffix}
# #define ${ns}_${pref}${name}${suffix}
# #include <${prefix}$name$suffix>
# #endif
#
sub getXmlIncStrs {
	my $node=$_[0];
	my $ns=getNSIncStr(getXmlNS($node));
	my $prefix=getXmlAttr($node,"prefix","");
	my $suffix=getXmlAttr($node,"suffix","");
	my $pref0=$prefix; $pref0 =~ s/\//_/g if ($prefix);
	my $suf0=$suffix; $suf0 =~ s/\./_/g if ($suffix);
	
	$ns .= "_" if ($ns);
	if (isTrue($prefix)) {$prefix=$ns; $prefix =~ s/\_/\//g; }
	
	my ($v0,$v1,$s0,$s1);
	if (isXmlTrue($node,"system")) { $v0="<"; $v1=">"; }
	else {	$v0="\""; $v1="\"";	} 
	my $redef = isXmlTrue($node, "redefine");
	
	my @array;
	$s0 = getXmlText($node);
	my @a1 = arrayNormStr($s0);
	
	foreach my $name (@a1) {
		$s1=uc("${name}${suf0}"); $s1="${ns}${s1}"; 
		push(@array,"#ifndef ${s1}");
		push(@array,"#define ${s1}") if ($redef);
		push(@array,"#include ${v0}${prefix}${name}${suffix}${v1}");
		push(@array,"#endif\n");
	}
	return \@array;
}
sub getXmlSrcStrs {
	my $node=$_[0];
	my $ns=getNSIncStr(getXmlAttr($node,"namespace"));
	my $prefix=getXmlAttr($node,"prefix");
	my $suffix=getXmlAttr($node,"suffix");
	my $pref0=$prefix; $pref0 =~ s/\//_/g if ($prefix);
	my $suf0=$suffix; $suf0 =~ s/\./_/g if ($suffix);
	
	$ns .= "_" if ($ns);
	
	my ($v0,$v1, $s0);
	if (isXmlTrue($node,"system")) { $v0="<"; $v1=">"; }
	else {	$v0="\""; $v1="\"";	} 
		
	my @array;
	$s0 = getXmlText($node);
	my @a1 = arrayNormStr($s0);
	
	foreach my $name (@a1) {
		push(@array,"#include ${v0}${prefix}${name}${suffix}${v1}");
	}
	return \@array;
}

 #start,end}; dir(/); prefix(_); ns(::) 
sub getXmlNSStrs {
	my $ns =  normalizeNS (getXmlNS ($_[0]));	
	return ("","","","","","") if(length($ns)==0);
		
	my (@a0,@a1,@a2);
	foreach my $s0 (split(/\./,,$ns)) {
		push(@a0, $s0);
		push(@a1, "namespace ${s0} {");
		push(@a2, "}");
	}
	
	return (join("\n", @a1), join("\n", @a2), join("/", @a0)."/", 
	        join("_", @a0)."_", join("::",@a0)."::", $ns );	
}
##############################################
sub getHFileIncs {
    my $cnode=$_[0];	
	my $name=getXmlAttr($cnode,"name");
	my @nss=getXmlNSStrs($cnode);
	my $s0="$nss[3]${name}_H";
	my $ns=$nss[5];
	
	my @a0=("#ifndef $s0", "#define $s0\n"); 
	
	foreach my $node ($cnode->getChildrenByTagName("h") ) { 
		if (isXmlTrue($node,"self") && length($ns)>0) {
			$node->setAttribute("namespace", $ns);
		}
		push(@a0, @{getXmlIncStrs($node)});		
	}	
	push @a0, ("$nss[0]\n",) if (length($nss[0])>0);
	
	my @a1=($nss[1], "\n#endif /* end of ${s0} */");	
	return (\@a0, \@a1);
}
sub getCFileIncs {
    my $cnode=$_[0];
	my $name=getXmlAttr($cnode,"name");
	my @nss=getXmlNSStrs($cnode);
	my $ns=$nss[5];	
	my @a0; 

	foreach my $node ($cnode->getChildrenByTagName("c") ) {
		if (isXmlTrue($node,"self") && length($ns)>0) {
			$node->setAttribute("namespace", $ns);
		}		
		push(@a0, @{getXmlSrcStrs($node)});		
	}	
	
	my $s0="#include <$nss[2]${name}.h>";
	if (isXmlTrue($cnode,"preset")) { unshift @a0, ($s0."\n", ); 
	} else { push @a0, ($s0, );	}
	push @a0, ($nss[0],);
		
	my @a1=($nss[1], );	
		
	return (\@a0,\@a1);	
}
##############################################
##############################################
sub getXmlRoot {
	my $xfile=$_[0];
	return readXmlRoot($xfile) if (-f $xfile);
	my $dom = XML::LibXML::Document->createDocument( '1.0', 'utf-8');
	my $nodename="";
	if ($xfile =~ m/.+\/(\w)+\.xml$/) {
		$nodename=$1;
	}
	my $root = $dom->createElement( $nodename);
	$dom->setDocumentElement($root);
	return $root;
}
# copy template xml and replace name and version
sub copyTemplateXml {
	my ($srcxfile,$dstxfile,$name,$s0,$ns)=@_;
	my $root = (-f $dstxfile) ? getXmlRoot($dstxfile) : getXmlRoot($srcxfile);	 
	
	if ($root->hasAttribute("name")) {
		$root->setAttribute("name",$name);
	} elsif ($root->hasAttribute("file")) {
		$root->setAttribute("file",$name);
	}
	
	if (@_ == 4) {
		if ($root->hasAttribute("version")) {
			$root->setAttribute("version",$s0);
		} elsif ($root->hasAttribute("ns")) {
			$root->setAttribute("ns",$s0);
		} elsif ($root->hasAttribute("namespace")) {
			$root->setAttribute("namespace",$s0);
		}
	} elsif ( @_ >= 5) {
		$root->setAttribute("version",$s0);
		$root->setAttribute("namespace",$ns);
	}
	
	writeXml($root,$dstxfile);
}

#################
sub hasChild {
	my $root=$_[0];
	my $val=$_[1];
	my $attr=(@_>2)?$_[2]:"name";
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		next if ($node->nodeType == XML::LibXML::XML_COMMENT_NODE);
		my $s0 = getXmlAttr($node,$attr,"");
		return 1 if ($s0 eq $val);
	}
	return 0;
}	
#################
sub readXmlDoc {
	my $parser = new XML::LibXML;
	return $parser -> parse_file($_[0]); # return doc
}

sub readXmlRoot {
	my $parser = new XML::LibXML;
	my $doc = $parser -> parse_file($_[0]);
	my $root = $doc -> getDocumentElement();
=begin comment
	$elname = $rootel -> getName();
	print "Root element is a $elname and it contains ...\n";

	@kids = $rootel -> childNodes();
	foreach $child(@kids) {
        $elname = $child -> getName();
        @atts = $child -> getAttributes();
        print "$elname (";
        foreach $at (@atts) {
                $na = $at -> getName();
                $va = $at -> getValue();
                print " ${na}[$va] ";
                }
        print ")\n";
        }
=end comment
=cut	
	return $root;
}
 
sub writeXml {
	my ($root, $xfile)=@_;	
	open XML, ">${xfile}" or die "cannot open ${xfile}";
	print XML $root->toString(1); #(), or 1,2
	close XML;
}

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
sub splitXmlText {   
   return splitText(trimNewLine($_[0]->textContent));
}

# save xml node in a file
# arg1: xml node
# arg2: xml file name
my $XML_FORMAT=1;  #dent output
sub xmlFile {
    $_[0]->ownerDocument->toFile($_[1], $XML_FORMAT);
}
sub createDoc {
  my $doc = XML::LibXML::Document->new("1.0");
  my $root = $doc->createElement($_[0]);
  $doc->setDocumentElement($root);
  return $doc;
}
###############################################################
# get pkg_home from pkgname and env vars
###############################################################
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
sub addNodeText {
	my ($node,$tagname,$t0)=@_;

	foreach my $n0 ($node->getChildrenByTagName($tagname)) {
		print "node0=",$n0->toString(1),"\n";
		foreach my $n1 ($n0->childNodes) { 
			print "node1=",$n1->toString(1),"\n";	
			next if ($n0->nodeType != XML_TEXT_NODE);
			print "text value:",  $n0->nodeValue, "\n";
		}
	}
	
	return $node;
}
####################################################
###########################################