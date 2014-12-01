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
   print "  pkg_init pkg_name [homedir]\n";
}
# update name of package.xml
sub updatePackageXFile {
    my ($xfile,$pname)=@_;
    my $root=xmlRoot($xfile,"package");
    $root->setAttribute("name", $pname);
    xmlFile($root, $xfile);
}

# update name of product.xml
sub updateProductXFile {
    my ($xfile,$pname)=@_;
    my $root=xmlRoot($xfile,"product");
    $root->setAttribute("name", $pname);
    
    xmlFile($root, $xfile);
}

# init package: pkg_name pkg_dir
sub init_pkg {
   my ($pname, $pdir)=@_;

   if (not -d $pdir) {
      if (-f $pdir) { error ("pkg home dir ${pdir} exists as a file: remove it first"); return; }
      info("create pkg home dir ${pdir}");
      system("mkdir -p $pdir");
   }
   
   my $mypdir="$pdir/meta/pkg";
   my $xdir="${dirname}/../meta/pkg";
   
   # copy meta/xml/*.xml to $pdir/meta/pkg
   system("mkdir -p $mypdir");
   system("cp $xdir/*.xml $mypdir");
   
   #update package name: 
   my $xfile="$mypdir/package.xml";
   updatePackageXFile($xfile,$pname);
   
   $xfile="$mypdir/product.xml";
   updateProductXFile($xfile,$pname);
   
   print " cd ${mypdir}\n";
   #system("chdir ${mypdir}");
   chdir($mypdir);
}

print "[start script]: $0\n";

my $work=1;
if ($#ARGV < 0 ) { usage(); $work=0;}

foreach my $arg ( @ARGV){  
    if (is_help($arg)) { usage(); $work=0; last;}
}

if ($work) {
    my $pkg_name=$ARGV[0];
    my $pkg_dir="$dir/$pkg_name";
    if ($#ARGV>=1) { $pkg_dir = $ARGV[1]; }
    
    if (is_name($pkg_name)) {
        if (is_dir($pkg_dir)) {
            print ("  init package $pkg_name in $pkg_dir\n");
            init_pkg($pkg_name, $pkg_dir);
        } else {
            print "  invalid pkg dir ${pkg_dir}. Should be in format:";
            print " ^[\/a-zA-Z][a-zA-Z0-9_\/]*[\/a-zA-Z0-9_]\$\n";
        }
    } else {
        print "  invalid pkg name ${pkg_name}. Should be in format:";
        print " ^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9_]\$\n";
    } 
}

print "[end script]: $0\n";
