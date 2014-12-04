#!/usr/bin/perl -w

#
# generate meta/*.xml from meta/class.cfg.
#
use strict;
use warnings;

use common;

my $SP3=common::SPACES;

sub generateCFile {
	my $ns="";
	my @array;
	
	foreach my $line (@{readArray($_[0])}) {
		$line=trim($line);
		if ($line =~ /^namespace$/i ) {
			$ns=$line;
		} 
	}
}

#my $argc=@ARGV; print "argc=", $argc
my ($fname, $s0, $node);
foreach my $arg (@ARGV) {
	my (@harray, @hsuf, @carray); 
	my $root = readXmlRoot($arg);
	my $fname=getXmlAttr($root, "file");
	next unless ($fname);
	print "generate class *.h/*.cc from file ${arg}\n";
	 	
	my $ns=getXmlAttr($root, "namespace");
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
	foreach $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^inc$/i) || ($name =~ /^h$/i)) {
			next;			
		} elsif ( ($name =~ /^src$/i) || ($name =~ /^c$/i)) {
			next;
		} elsif ( $name =~ /^macro$/i ) { #macro

		} elsif ( $name =~ /^typedef$/i ) {#typedef

		} elsif ( $name =~ /^decl$/i ) {#prefix declare
						
		} elsif ( $name =~ /^func$/i ) { #func
						
		} elsif ( $name =~ /^cfunc$/i ) { # c functions										
						
		} elsif ( $name =~ /^union$/i ) { # union
						
		} elsif ( $name =~ /^struct$/i ) { # struct
						
		} elsif ( $name =~ /^class$/i ) { # class
			
		} else {
			print "\nunknown node:node name=${name}\n", $node->toString();
		} 
	}
	
	## end enclosing namespace
	my @nsarray1=@{getNSSuffixStrs($num)};
	
	push(@harray, @nsarray1); push(@harray,"") if ($num);
	push(@carray, @nsarray1); push(@carray,"") if ($num);
	
	push(@harray,"#endif");
	
	writeArray("${fname}.h", \@harray);	
	my $len=@carray; $num += 1;
	#print "carray: num=${num}; size=",length(@carray), ":", $len,"\n", join(":",@carray),"\n";
	writeArray("${fname}.cc", \@carray) if ($len>$num); 
}

