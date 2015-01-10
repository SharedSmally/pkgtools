#!/usr/bin/perl -w

use strict;
use warnings;

use common;
use commonXml;
use commonXmlAction;

use commonMD5 qw(parseLabelFiles);
#use commonCFile qw(genCFileCode );

sub generateModule {
	my $root=$_[0];
	my $name=getXmlAttr($root,"name");
	my $ns=getXmlNS($root);
	
	my $cmdir = cmdDir(); $cmdir .= "../xml";
	my @mods;
	
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $xname=$node->getName();
		if ($xname =~ /^cfile$/i) {
			my $a0 = genCFile($node, $ns, "${cmdir}/cfile.xml");
		} elsif ($xname =~ /^cfiles$/i) {
			my $a0 = genCFile($node, $ns, "${cmdir}/cfile.xml");
		}	
	}
	
	return $ns;
}
###########################
my $xfile="meta/module.xml";
unless (-f $xfile) { print " module not exist ${xfile}\n"; exit(1);}

print " generate module from ${xfile}\n";
my $ns = generateModule(getXmlRoot($xfile));

my @a0 = lsArray("meta/*.xml");
system("mkdir -p src");

my $tdir="../"; my $hdir;
my $cnt=0;
while ($cnt<3) {
	$hdir="${tdir}inc/"; last if (-d "${hdir}");
	$hdir="${tdir}include/"; last if (-d "${hdir}");
	$tdir .= "../"; ++$cnt ;
}
unless (-d $hdir) {print " inc not exist ${hdir}\n"; exit(2);}
my $ns1 = getNSDirStr($ns);
#print ("mkdir -p ${hdir}${ns1}; ln -s ${hdir}${ns1} inc");
system("mkdir -p ${hdir}${ns1};");
#my $cmd ="ln -s ${hdir}${ns1} inc"; print "cmd=${cmd}\n";
system("ln -s ${hdir}${ns1} inc/; rm -rf ${hdir}${ns1}/*");

for my $cfile (@a0) {		
	next if (trim($cfile) eq "meta/module.xml" );
	print " generate *.h/*.cc from ${cfile}\n";
	my $cnode = getXmlRoot($cfile);
	my $fname = getXmlAttr($cnode,"name","");
	$fname = getXmlAttr($cnode,"file") if (length($fname)==0);
	
	my @srcs;
	push (@srcs, "${fname}.cc") if (-f "${fname}.cc");
	push (@srcs, "inc/${fname}.h") if (-f "inc/${fname}.h");
	
	my $code = parseLabelFiles(\@srcs);	
	my ($h0,$c0)=genCFileCode($cnode,$code);
	
	writeArray("${fname}.h",$h0);
	writeArray("${fname}.cc",$c0);
	
	#system("mv ${fname}.h ${hdir}${fname}.h");
	#trimFile("src/${fname}.h","${fname}.h");
	#trimFile("src/${fname}.cc","${fname}.cc");
};
