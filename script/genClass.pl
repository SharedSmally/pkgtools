#!/usr/bin/perl -w

#
# generate *.h and *.cc from meta/*.xml
#
use strict;
use warnings;

use common;
use commonXml;
use commonCCode; # genMacroCode,genTypedefCode, genDeclCode
use commonFunc;  # genFuncCode, genCfuncCode
use commonClass; # genUnionCode, genClassCode

my $SP3=common::SPACES;

#
# generate *.h/*.cc from meta/*.xml
#
sub generateClass {	 
	my $root = readXmlRoot($_[0]);
	my $fname=getXmlAttr($root, "file");
	next unless ($fname);
	print "generate class *.h/*.cc from file $_[0]\n";
	
	my ($s0, $node);
	my (@harray, @hsuf, @carray);
	 	
	my $ns=getXmlAttr($root, "namespace");
	my $nsdir=getNSDirStr($ns);
	$s0=getNSIncStr($ns); $s0 .= "_" if ($ns);
	$s0 .= uc($fname); $s0 .= "_H";
	push(@harray,"#ifndef ${s0}");
	push(@harray,"#define ${s0}\n");
	#namespace
	
	$s0=getNSDirStr($ns); 
	$s0 = "#include <${s0}/${fname}.h>";	push(@carray,$s0);
	
	#include headers in *.h
	foreach $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^inc$/i) || ($name =~ /^h$/i)) {
			if ($name =~ /^inc$/i) {
				#$node->setAttribute("ns",$ns);
				$node->setAttribute("redefine","false");
				$node->setAttribute("prefix",$nsdir);
				$node->setAttribute("suffix",".h");
			}
			push(@harray, @{getXmlIncStrs($node)});			
		}
	}
	#include headers in *.cc
	foreach $node ($root->childNodes()) { 
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^src$/i) || ($name =~ /^c$/i) || ($name =~ /^cc$/i) ) {
			push(@carray, @{getXmlSrcStrs($node)});			
		}
	}
	
	#open closing namespace
	my @nsarray0=@{getNSPrefixStrs($ns)};
	my $num = @nsarray0;
	push(@harray, @nsarray0); push(@harray,"") if ($num);
	push(@carray, @nsarray0); push(@carray,"") if ($num);	
	
	# included in namespace:macro/union/class/struct/typedef/func/cfunc/
	my ($h0, $h1, $c0);		
	foreach $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		next if ($node->nodeType == XML::LibXML::XML_COMMENT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^inc$/i) || ($name =~ /^h$/i))    { next; }		
		elsif ( ($name =~ /^src$/i) || ($name =~ /^c$/i)) { next; }			
		elsif ( $name =~ /^macro$/i ) { #macro
            ($h0, $h1, $c0) = genMacroCode($node);
		} elsif ( $name =~ /^typedef$/i ) {#typedef
		    ($h0, $h1, $c0) = genTypedefCode($node);
		} elsif ( $name =~ /^decl$/i ) {#prefix declare
			($h0, $h1, $c0) = genDeclCode($node);			
		} elsif ( $name =~ /^func$/i ) { #func
			($h0, $h1, $c0) = genFuncCode($node);			
		} elsif ( $name =~ /^cfunc$/i ) { # c functions										
		    ($h0, $h1, $c0) = genCfuncCode($node);
		} elsif ( $name =~ /^union$/i ) { # union
			($h0, $h1, $c0) = genUnionCode($node);			
		} elsif ( $name =~ /^struct$/i ) { # struct
			($h0, $h1, $c0) = genClassCode($node);
		} elsif ( $name =~ /^class$/i ) { # class
			($h0, $h1, $c0) = genClassCode($node);
		} else {
			print "\nunknown node:node name=${name}\n", $node->toString();
			$h0=""; $h1=""; $c0="";
		}
		push(@harray, @{$h0}) if ($h0);
		push(@hsuf, @{$h1}) if ($h1);
		push(@carray, @{$c0}) if ($c0);		 
	}
	
	push(@harray, @hsuf);
	
	## end enclosing namespace
	my @nsarray1=@{getNSSuffixStrs($num)};	
	
	push(@harray, @nsarray1); push(@harray,"") if ($num);
	push(@carray, @nsarray1); push(@carray,"") if ($num);
	
	push(@harray,"#endif");
	
	writeArray("${fname}.h", \@harray);	
	my $len=@carray; $num += 1;
	writeArray("${fname}.cc", \@carray) if ($len>$num);

    my $incdir="";
    if (-d "../../include")    { $incdir="../../include/"; }
    elsif (-d "../../include") { $incdir="../../inc/"; }
    return unless ($incdir);
    $incdir .= $nsdir;
    system("mkdir -p ${incdir}") unless (-d ${incdir});
    $incdir .= "/" unless ($incdir =~ /\$/);
    system("mv ${fname}.h ${incdir}${fname}.h"); 
}

my $xmls = `ls meta/*.xml`;
foreach my $xmlfile (split(/\s+/, $xmls)) {
	print "generate *.h/*.cc from file ${xmlfile}\n";
    generateClass($xmlfile);		
} 


#my $fnmae="meta/class.cfg";
#generateClassXml(-f $fname )  if (-f $fname) ;

#my $argc=@ARGV; print "argc=", $argc