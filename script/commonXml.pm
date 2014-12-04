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
our @EXPORT = qw(isXmlFalse isXmlTrue 
                 getXmlIncStrs getXmlSrcStrs
                 getXmlAttr readXmlRoot getXmlRoot writeXml) ;

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
sub getXmlAttr {
	my ($node, $attr)=@_;
	my $len = @_;
	my $val="";  $val=$_[2] if ($len>=3);
	return ($node->hasAttribute($attr)) ?  $node->getAttribute($attr) : $val;		
}
sub getXmlText {
	return trim($_[0]->textContent);			
}
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
	my $ns=getNSIncStr(getXmlAttr($node,"ns"));
	my $prefix=getXmlAttr($node,"prefix","");
	my $suffix=getXmlAttr($node,"suffix","");
	my $pref0=$prefix; $pref0 =~ s/\//_/g if ($prefix);
	my $suf0=$suffix; $suf0 =~ s/\./_/g if ($suffix);
	
	$ns .= "_" if ($ns);
	
	my ($v0,$v1,$s0,$s1);
	if (isXmlTrue($node,"system")) { $v0="<"; $v1=">"; }
	else {	$v0="\""; $v1="\"";	} 
	my $redef = isXmlTrue($node, "redefine");
	
	my @array;
	$s0 = getXmlText($node);
	my @a1 = arrayNormStr($s0);
	
	foreach my $name (@a1) {
		$s1="${ns}${pref0}${name}${suf0}"; $s1=uc($s1);
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
	open XML, ">${xfile}";
	print XML $root->toString(2); #(), or 1,2
	close XML;
	# save
  	#open my $out, '>', 'out.xml';
  	#binmode $out; # as above
  	#$doc->toFH($out);
	# or
	# print {$out} $doc->toString();	
}
###########################################