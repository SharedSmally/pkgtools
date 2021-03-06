#!/usr/bin/perl -w

use strict;
use warnings;

use common qw(cmdDir writeArray);
use commonMake qw(makeSubdirsMk);
use commonXml qw(getXmlRoot getXmlAttr getXmlTextArray getXmlNS copyTemplateXml) ;
use commonXmlAction qw(genXmlDirs genXmlFiles genXmlDirFiles genXmlLink genXmlCopy genXmlCommand);

sub genXmlApp {
	my ($node,$version, $xfile)=@_;

	my $myver=getXmlAttr($node,"version",$version);
	my @names=@{getXmlTextArray($node)};

	foreach my $name (@names) {
		print "   create application ${name} version=${myver}\n";
		system("mkdir -p appsrc/${name}/meta");
		copyTemplateXml($xfile,"appsrc/${name}/meta/application.xml",$name,$myver);
	};	
	
	return \@names;
}
sub genXmlLib {
	my ($node,$version, $xfile)=@_;
	my $myver=getXmlAttr($node,"version",$version);
	my $ns=getXmlNS($node,"ns");
	my @names=@{getXmlTextArray($node)};

	foreach my $name (@names) {
		print "   create library ${name} version=${myver}\n";
		system("mkdir -p libsrc/${name}/meta");
		copyTemplateXml($xfile,"libsrc/${name}/meta/library.xml",$name,$myver,$ns);
	};	
	return \@names;
}
sub genXmlGeneric {
	return genXmlLib($_);
}

sub generatePkgEnv {
	my $cdir=`pwd`;
	my @array=("#!/usr/bin/bash", "export PKG_HOME=${cdir}" );
	writeArray("meta/build.sh", \@array);	
}
sub generatePackage {
	my $root=$_[0];	
	my $name=getXmlAttr($root,"name");		
	my $version=getXmlAttr($root,"version","1.0.0");
	my $cmdir = cmdDir(); $cmdir .= "../xml";
	
	my (@apps, @libs, @svcs, @pdus, @dbs, @xmls, @srcs); my $a0;
	
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $xname=$node->getName();
		if ($xname =~ /^files$/i) { genXmlFiles($node); }	
		elsif ($xname =~ /^dirs$/i) { genXmlDirs($node); }
		elsif ($xname =~ /^dirfiles$/i) { genXmlDirFiles($node); }
		elsif ($xname =~ /^link$/i) { genXmlLink($node); }
		elsif ($xname =~ /^copy$/i) { genXmlCopy($node); }
		elsif ($xname =~ /^cmd$/i)  { genXmlCommand($node); }
		elsif ($xname =~ /^command$/i) { genXmlCommand($node); }
		
		elsif ($xname =~ /^app$/i)         { 
			$a0 = genXmlApp($node,$version,"${cmdir}/application.xml"); push(@apps, @{$a0}); 
		} elsif ($xname =~ /^application$/i) { 
			$a0 = genXmlApp($node,$version,"${cmdir}/application.xml"); push(@apps, @{$a0});
		} elsif ($xname =~ /^lib$/i)     { 
			$a0 = genXmlLib($node,$version,"${cmdir}/library.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^library$/i) { 
			$a0 = genXmlLib($node,$version,"${cmdir}/library.xml"); push(@libs, @{$a0});			
		} elsif ($xname =~ /^svc$/i)     { 
			$a0 = genXmlService($node,$version,"${cmdir}/service.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^service$/i)     { 
			$a0 = genXmlService($node,$version,"${cmdir}/service.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^prot$/i)     {
			$a0 = genXmlProtocol($node,$version,"${cmdir}/protocol.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^protocol$/i) { 
			$a0 = genXmlProtocol($node,$version,"${cmdir}/protocol.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^db$/i)      { 
			$a0 = genXmlDatabase($node,$version,"${cmdir}/database.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^database$/i){ 
			$a0 = genXmlDatabase($node,$version,"${cmdir}/database.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^report$/i)   { 
			$a0 = genXmlReport($node,$version,"${cmdir}/report.xml"); push(@libs, @{$a0});
		} elsif ($xname =~ /^xsd$/i)      { 
			$a0 = genXmlXsd($node,$version,"${cmdir}/xsd.xml"); push(@libs, @{$a0});
		} else { 
			if (-f "${cmdir}/${xname}.xml") {
				$a0 = genXmlGeneric($node,$version,"${cmdir}/${xname}.xml");
				push(@libs, @{$a0});
			}
		}
	}
	
	#create makefile for libs,apps	
	if (length(@libs)>0) { makeSubdirsMk("libsrc/makefile", \@libs); push(@srcs,"libsrc");}
	if (length(@apps)>0) { makeSubdirsMk("appsrc/makefile", \@apps); push(@srcs,"appsrc");}
	if (length(@srcs)>0) {makeSubdirsMk("makefile", \@srcs); }
	generatePkgEnv();
}

###########################
my $xfile="meta/package.xml";
unless (-f $xfile) { print " package not exist ${xfile}\n"; exit(1);}

print " generate package from ${xfile}\n";
generatePackage(getXmlRoot($xfile));