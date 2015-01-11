#!/usr/bin/perl -w

use strict;
use warnings;
#use Env;

use common;
use commonXml;
use commonXmlAction qw(genCFile genCFileCode);
use commonMake qw(makeModMk);

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

my $pkghome =  $ENV{'PKG_HOME'};
unless ($pkghome) {print "PKG_HOME is not set", exit 1; };
unless (-d "${pkghome}/meta") {print "PKG_HOME/meta does not exit", exit 1; };

print " Package home dir: ${pkghome}\n" ;

system("mkdir -p src");
my $hdir="${pkghome}/include/";
unless (-d $hdir) {print "package include dir ${hdir} not exist\n"; exit(2);}

my $ns1 = getNSDirStr($ns); 
system("mkdir -p ${hdir}${ns1};") unless (-d "${hdir}${ns1}");
`rm inc` if (-f "inc");
system("ln -s ${hdir}${ns1} inc; rm -rf ${hdir}${ns1}/*");

my @a0 = lsArray("meta/*.xml");
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
	
	writeArray("inc/${fname}.h",$h0);
	writeArray("${fname}.cc",$c0);	
};

makeModMk("makefile");