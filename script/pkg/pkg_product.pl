#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;

my $dir = getcwd;
my $dirname  = dirname($0);

use Common qw( is_name is_dir is_help info debug warn error);  # import listed items
use CommonXml qw(xmlRoot xmlFile);

# return package home dir based on $pkg_home_dir/meta/pkg/product.xml
sub getHomeDir {
   return dirname(dirname($dir));;
}

# echo the command-line arguments
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
   #chdir($mypdir);
}
###########################################################################

###########################################################################
print "[start script]: $0\n";

my $hdir=getHomeDir();
my $xfile="./layout.xml";
if (-f $xfile) {
    info("update product layout based on $xfile");
    updateLayout($hdir, xmlRoot($xfile));
}

my $xfile="./product.xml";
if (-f $xfile) {
    info("update product based on $xfile");
    updateProduct($hdir, xmlRoot($xfile));
} else {
    print ("  no ./product.xml exits\n"); 
}

print "[end script]: $0\n";
###########################################################################
