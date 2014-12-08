#!/usr/bin/perl -w

use strict;
use warnings;

use commonXml;

sub createPackage {
	my ($name, $dir, $version, $xfile) = @_;
	print "   Create package: name=${name}, homedir=${dir}; version=${version}\n";
	print "     template file: ${xfile}\n";
	my $myxfile="${dir}/meta/package.xml";
	my $root = getXmlRoot($xfile);
	$root->setAttribute("name",$name);
	$root->setAttribute("version",$version);
	writeXml($root,$myxfile);
}
sub createProduct {
	my ($name, $dir, $version, $xfile) = @_;
	print "   Create product: name=${name}, homedir=${dir}; version=${version}\n";
	print "     template file: ${xfile}\n";
	my $myxfile="${dir}/meta/product.xml";
	my $root = getXmlRoot($xfile);
	$root->setAttribute("name",$name);
	$root->setAttribute("version",$version);
	writeXml($root,$myxfile);
}

# driver for all operations:
my $argc=@ARGV; # print "argc: ${argc}";
my $mydir=`dirname $0`;
$mydir =~ s/^\s+//; $mydir =~ s/\s+$//;
$mydir .= "/" unless ( $mydir =~ /\/$/ );

my $cmd="";
if ( (-f "meta/pkg.xml") || (-f "meta/package.xml")) { 
	$cmd = "genPkg.pl"; 
} elsif ((-f "meta/prod.xml") || (-f "meta/product.xml")) {
	$cmd = "genProd.pl";
} elsif ((-f "./meta/deploy.xml") || (-f "./meta/deployment.xml")) {
	$cmd = "genDeploy.pl";

} elsif ((-f "./meta/lib.xml") || (-f "./meta/library.xml")) {
	$cmd = "genLib.pl"; #also handle meta/*class.xml
} elsif ((-f "./meta/mod.xml") || (-f "./meta/module.xml")) {
	$cmd = "genModule.pl"; #also handle meta/*class.xml
	 
} elsif ((-f "./meta/svc.xml") || (-f "./meta/service.xml")) {
	$cmd = "genService.pl"; #also handle meta/*class.xml
} elsif ((-f "./meta/app.xml") || (-f "./meta/application.xml")) {
	$cmd = "genApp.pl";
	
} elsif ((-f "./meta/prot.xml") || (-f "./meta/protocol.xml")) {
	$cmd = "genProtocol.pl"; #also handle meta/*msg.xml
#} elsif ((-f "meta/msg.cfg") || (-f "meta/message.xml")) {
#	$cmd = "genMsg.pl";

} elsif ((-f "meta/db.cfg") || (-f "meta/database.xml")) {
	$cmd = "genDb.pl"; #also handle meta/table*.xml		
	
} elsif ((-f "meta/report.cfg") || (-f "meta/report.xml")) {
	$cmd = "genReport.pl"; # also handle meta/*record.xml
	
} elsif ((-f "meta/asn.cfg") || (-f "meta/asn.xml")) {
	$cmd = "genAsn.pl";
#} elsif ((-f "meta/db.cfg") || (-f "meta/database.xml")) {
#	$cmd = "genDb.pl";
}

if (length($cmd)>0) {
	$cmd = "${mydir}/${cmd}";
	print "Running ${cmd} ......\n";
	system($cmd); exit(0); 
}

if ($argc==0) {
	print "Usage: pkg pkgname [pkg|prod] [pkgdir] [version]\n";
	exit(0);
}

my $name=$ARGV[0];
my $type = ($argc>=2) ? $ARGV[1] : "pkg";

my $dir = ($argc>=3) ? $ARGV[2] : $name;
if (-d $dir) { print "   package directory [${dir}] already exists\n"; exit(1);}
if (-f $dir) { print "   package directory [${dir}] exists as a file\n"; exit(2);}

my $version = ($argc>=3) ? $ARGV[3] : "1.0.0";

$dir .= "/" unless ( $dir =~ /\/$/ );
system("mkdir -p ${dir}meta");

print "type=${type}\n";
if ($type =~ /^pkg$/i) {
	my $xfile="${mydir}../xml/package.xml"; 
	createPackage($name,$dir,$version,$xfile); 
} else {
	my $xfile="${mydir}../xml/product.xml"; 
	createProduct($name,$dir,$version,$xfile);
}

