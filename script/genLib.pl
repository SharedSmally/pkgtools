#!/usr/bin/perl -w

use strict;
use warnings;

use common;
use commonXml;
use commonXmlAction;
use commonMake qw(makeSubdirsMk makeLibMk);

#specific namespace
#<module namespace="">list-of-modules-share-ns</module>
#namespace={lib_namespace}.name
#<module>list-of-individual-module-ns</module>
#
sub genModule {
	my ($node,$ns,$xfile)=@_;
	my $myns = getXmlNS($node);
	my @mods;	
	if (length($myns)==0) {
        $ns .= "." if (length($ns)>0);				
		foreach my $name (@{getXmlTextArray($node)}) {
			system("mkdir -p ${name}/meta");  push(@mods,$name);
			copyTemplateXml($xfile,"${name}/meta/module.xml",$name,"$ns${name}");
		}
	} else {
		foreach my $name (@{getXmlTextArray($node)}) {
			system("mkdir -p ${name}/meta");push(@mods,$name);
			copyTemplateXml($xfile,"${name}/meta/module.xml",$name,"$myns");
		}		
	}
	return \@mods;
}

sub generateLibrary {
	my $root=$_[0];
	my $name=getXmlAttr($root,"name");
	my $ns=getXmlNS($root);
	my $version=getXmlAttr($root,"version","1.0.0");	
	my $cmdir = cmdDir(); $cmdir .= "../xml";
	my @mods;
	
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $xname=$node->getName();
		if ( ($xname =~ /^module$/i) || ($xname =~ /mod/i) ) {
			my $a0 = genModule($node, $ns, "${cmdir}/module.xml");	push(@mods, @{$a0});
		} elsif ($xname =~ /^cfile$/i) {
			my $a0 = genCFile($node, $ns, "${cmdir}/cfile.xml");
		} elsif ($xname =~ /^cfiles$/i) {
			my $a0 = genCFile($node, $ns, "${cmdir}/cfile.xml");
		}	
	}
	
	if (length(@mods)>0) {
		makeSubdirsMk("makefile", \@mods); 
	} else {
		makeLibMk("makefile", $name, $version); 
	}
}
###########################
my $xfile="meta/library.xml";
unless (-f $xfile) { print " library not exist ${xfile}\n"; exit(1);}

print " generate library from ${xfile}\n";
generateLibrary(getXmlRoot($xfile));