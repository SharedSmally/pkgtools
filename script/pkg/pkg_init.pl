#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;

my $dir = getcwd;
my $dirname  = dirname($0);

use Common qw( is_name is_dir is_help info debug warn error);  # import listed items
use CommonXml qw(xmlRoot xmlFile);

# echo the command-line arguments
sub usage {
   print "  pkg_init.pl pkgname pkgdir pkgversion pkgtype\n";
}
# update name of package.xml
sub updatePackageXFile {
    my ($xfile,$pname,$version)=@_;
    my $root=xmlRoot($xfile,"package");
    $root->setAttribute("name", $pname);
    $root->setAttribute("version", $version);
    xmlFile($root, $xfile);
}

# update name of product.xml
sub updateProductXFile {
    my ($xfile,$pname,$version)=@_;
    my $root=xmlRoot($xfile,"product");
    $root->setAttribute("name", $pname);
    $root->setAttribute("version", $version);    
    xmlFile($root, $xfile);
}

# init package: pkg_name pkg_dir
sub init_pkg {
   my ($pname, $pdir, $pversion,$ptype)=@_;
   
   if (not -d $pdir) {
      if (-f $pdir) { error ("pkg home dir ${pdir} exists as a file: remove it first"); return; }
      info("create pkg home dir ${pdir}");
      system("mkdir -p $pdir");
   }
   info("init package ${pname} under director ${pdir}");
   
   # copy meta/xml/*.xml to $pdir/meta/pkg
   my $mypdir="$pdir/pkg";
   my $xdir="${dirname}/../meta/pkg";
   system("mkdir -p $mypdir");
   system("cp $xdir/*.xml $mypdir");

   # copy meta/makeincs/* to $pdir/meta/makeincs
   $mypdir="$pdir/pkg/makeincs";
   $xdir="${dirname}/../meta/makeincs";
   system("mkdir -p $mypdir");
   system("cp $xdir/* $mypdir");

   # copy meta/makeincs/* to $pdir/meta/makeincs
   $mypdir="$pdir/pkg/template";
   $xdir="${dirname}/../meta/template";
   system("mkdir -p $mypdir");
   system("cp $xdir/* $mypdir");
   
   #update package name & version:
   $mypdir="$pdir/pkg";    
   if ( ($ptype =~ m/^pkg$/i) || ($ptype =~ m/^package$/i) )
   {
   	   updatePackageXFile("${mypdir}/package.xml",$pname,$pversion);
   	   system("rm -rf ${mypdir}/product.xml");
   } else {
   	   updatePackageXFile("${mypdir}/product.xml",$pname,$pversion);
   	   system("rm -rf ${mypdir}/package.xml");	
   }         
   #print " cd ${mypdir}\n"; system("cd ${mypdir}");   
}

#########################################################
#    Entry Point
#########################################################
print "[start script]: $0\n";
#print "cmd count=", $#ARGV;

foreach my $arg ( @ARGV){  
    if (is_help($arg)) { usage(); exit 0;}
}
if ($#ARGV < 3 ) { usage(); print "[end script]: $0\n"; exit 0;}

my ($name,$home,$version,$type)=@ARGV;
    
unless (is_name($name)) {
    print "  invalid pkg name ${name}. Should be in format:";
    print " ^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9_]\$\n";
    print "[end script]: $0\n"; exit 1;
}
unless (is_dir($home)) {
   print "  invalid pkg dir ${home}. Should be in format:";
   print " ^[\/a-zA-Z][a-zA-Z0-9_\/]*[\/a-zA-Z0-9_]\$\n";
   print "[end script]: $0\n"; exit 1;	
}
unless (  ($type =~ m/^prod$/i) || ($type =~ m/^product$/i) || 
        ($type =~ m/^pkg$/i) || ($type =~ m/^package$/i) ) {
   print "  invalid pkg type ${type}. Should be one of:";
   print "  prod | product | pkg | package \n";
   print "[end script]: $0\n"; exit 1;	
}

init_pkg($name, $home, $version, $type);

print "[end script]: $0\n";
#########################################################