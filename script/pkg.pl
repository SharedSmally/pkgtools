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

#!/usr/bin/perl -w

use strict;
#
# The driver for c/c++ package management based on 
#   autoconfig/automake and make. Borrow some 
#   concepts from maven pattern
# command:
#   pkg [command]  
#
#  available commands:
#   init pkg_name homedir
#   copy pkg_name [version]
#   update: no reconfig
#   config: update+reconfig
#   compile
#   test
#   deb|rpm|gz|bz2  (target=debug|opt|sdk|test|src)
#   install
#
# package layout:
#   pkg_name/
#    autoconfig
#    data;
#    meta/pkg/*.xml
#      *=package (package)
#        product (product)
#        layout
#        debian (debian package): used by deb
#        rpm (rpm package): used by rpm
#        tar (binary tar package: gz|bz2): used by gz|bz2
#
my @commands = qw(
   init copy
   config update
   compile test
   deb rpm gz bz2
   install echo
);

my @xml_commands = (
   "library","lib", "module", "service",
   "database","record","report",
   "message","protocol", "asn1",
   "xsd","dtd",
   "application", "app",
   "package", "product"
);

sub usage {
   print "usage: pkg\n";
   print "    using ./", join(".xml ./", @xml_commands), ".xml\n";
}

sub useCommand {
   print "usage: pkg [", join("|", @commands), "]\n";
}
#print "Arg num=", $#ARGV, "\n";

if ($#ARGV < 0 ) { #update based on xml file in current directory
    foreach my $cmd (@xml_commands) {
      if (-f "./${cmd}.xml")  {  system("pkg_${cmd}.pl");  exit(0); }
    }
    if (-f "./meta/pkg/package.xml" ) { # package home directory: reconfig 
       system("pkg_update.pl");  exit(0);
    }
    if (-f "./meta/pkg/product.xml" ) { # package home directory: reconfig 
       system("product_update.pl");  exit(0);
    }
    print " *** no well-known xml file found\n";  usage(); exit(0);
} else {
    my $str = $ARGV[0]; my $flag=0;
    if ($str =~ /^-h$|^-help$|^--help$/i) { useCommand(); exit(0);}
    foreach my $s0 (@commands) {
       if ($s0 eq $str) { $flag=1; last;}
    }
    if ($flag==0) {
        print " *** unknown command $str\n";  useCommand(); exit(1);
    }
    
    my $cmd = "pkg_$ARGV[0].pl ";
    if ($#ARGV > 0) { # extra arg
       foreach my $arg ( @ARGV[1..$#ARGV] ){  $cmd .=  "\"$arg\" ";  }
    }
    system("$cmd"); 
}
