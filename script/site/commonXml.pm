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
          getXmlTextArray copyTemplateXml hasChild
          getXmlIncStrs getXmlSrcStrs  getXmlNSStrs 
          getXmlAttr readXmlRoot getXmlRoot writeXml          
          ) ;

use common;
###########################################
# input: $xnode; $name
sub isXmlTrue {
	my ($node, $attr)=@_;
	return 1 if (!$node->hasAttribute($attr));
	return isTrue($node->getAttribute($attr));	
}
# input: $xnode; $name
sub isXmlFalse {
	my ($node, $attr)=@_;
	return 1 if (!$node->hasAttribute($attr));
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

 #start,end{; dir(/); prefix(_); ns(::) 
sub getXmlNSStrs {
	my $ns =  normalizeNS (getXmlNS ($_[0]));	
	return ("","","","","") if(length($ns)==0);
		
	my (@a0,@a1,@a2);
	foreach my $s0 (split(/\./,,$ns)) {
		push(@a0, $s0);
		push(@a1, "namespace ${s0} {");
		push(@a2, "}");
	}
	
	return (join("\n", @a1), join("\n", @a2), join("/", @a0)."/", 
	        join("_", @a0)."_", join("::",@a0)."::" );	
}

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
	#print "write xml file to ${xfile}\n";
	open XML, ">${xfile}";
	print XML $root->toString(1); #(), or 1,2
	close XML;
	# save
  	#open my $out, '>', 'out.xml';
  	#binmode $out; # as above
  	#$doc->toFH($out);
	# or
	# print {$out} $doc->toString();	
}
###########################################