#!/usr/bin/perl -w

use strict;
use warnings;

use common;
use commonXml;

sub generatePkg {
	my ($node,$version, $xfile)=@_;

	my $pkgversion=getXmlAttr($node,"version",$version);
	my @pkgs=@{getXmlTextArray($node)};

	foreach my $pkgname (@pkgs) {
		print "   create package ${pkgname} version=${pkgversion}\n";
		system("mkdir -p ${pkgname}/meta");
		copyTemplateXml($xfile,"${pkgname}/meta/package.xml",$pkgname,$pkgversion);
	};	
	return \@pkgs;
}
# in dpc
sub generateDeployConfig {
	my ($name,$version, $xfile)=@_;
	my $dir="dpc";
	print "   create depoly configuration for product ${name} version=${version}\n";
	system("mkdir -p ${dir}/meta");
	copyTemplateXml($xfile,"${dir}/meta/deploy.xml",$name,$version);
	return $dir;
}

sub generateProd {
	my $root=$_[0];
	my $name=getXmlAttr($root,"name");
	my $version=getXmlAttr($root,"version","1.0.0");
	my $cmdir = cmdDir();
	my $pkgxml="${cmdir}../xml/package.xml";
	my $dpcxml="${cmdir}../xml/deploy.xml";
	my @subdirs=("SUBDIRS = ", );
	
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $nodename=$node->getName();	
		if ( ($nodename =~ /^pkg$/i) || ($nodename =~ /^package$/i)) {
			my $s1 = generatePkg($node,$version,$pkgxml);
			push(@subdirs, @{$s1});
		} 
	}
	my $s0 = generateDeployConfig($name,$version,$dpcxml);

	# generate makefile
	push(@subdirs, $s0);
	writeArray("makefile", paddingArray(\@subdirs, " "x4, " \\"));
}

###########################
my $xfile="meta/product.xml";
unless (-f $xfile) { print " product not exist ${xfile}\n"; exit(1);}

print " generate product from ${xfile}\n";
generateProd( getXmlRoot($xfile));