#!/usr/bin/perl -w

use strict;
use warnings;

use commonXml;

sub generateProtocol {
	my $root=$_[0];
	my $name=getXmlAttr($root,"name");
	my $version=getXmlAttr($root,"version","1.0.0");
	
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $nodename=$node->getName();	
		if ($nodename =~ /^message$/i) {
			
		} elsif ($nodename =~ /^message$/i) {
			
		} 
	}
}
###########################
my $xfile="meta/package.xml";
unless (-f $xfile) { print " package not exist ${xfile}\n"; exit(1);}

print " generate protocol from ${xfile}\n";
generateProtocol(getXmlRoot($xfile));