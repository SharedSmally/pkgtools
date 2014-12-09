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
