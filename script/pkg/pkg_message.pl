#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x5;

my $dir = getcwd;
my $sdir = dirname(dirname($0)); #script homedir

use Common qw(info writeFile);
use CommonXml qw( xmlRoot );
use CommonImpt qw( getImports );
use CommonCMsg qw( updateCMsgMeta genCMsgCode);
use CommonPkg qw(getLibMk getMkFileLib);
# return package home dir based on $pkg_home_dir/meta/pkg/package.xml
sub getPackageDir {
   return dirname(dirname($dir));;
}

sub updateModule {
    my ($hdir, $xfile)=@_;
    
    info("update module based on $xfile");
    unless (-f $xfile) { print ("  no $xfile exits\n"); return; }

    my $libnode = xmlRoot($xfile);
    my $t1 = updateCMsgMeta($libnode); 
    
    my $impts = getImports($libnode);   # import mapping

    my (@hfiles, @cfiles,@tfiles);
    foreach my $t2 (@{$t1}) { # for each cfiles
        my $t3="meta/${t2}.xml";+
        my ($hasC, $utests) = genCMsgCode($libnode,$t3,$impts); 
        push(@hfiles,$t2);
        push(@cfiles,$t2) if ($hasC);  push(@tfiles,$utests) if ($utests);
    }
    #my $modname=$libnode->getAttribute("name");
    info("create Makefile.am");
    writeFile("Makefile.am",getLibMk($libnode, \@hfiles, \@cfiles, \@tfiles));
    
    info("create makefile");
    writeFile("makefile",getMkFileLib($libnode, \@hfiles, \@cfiles, \@tfiles));
}
###########################################################################
print "[start script]: $0\n";
 
my $hdir=getPackageDir();
if ($#ARGV==-1) { updateModule($hdir, "./lib.xml"); }
else { foreach my $arg (@ARGV) { updateModule($hdir, $arg); } }

print "[end script]: $0\n";
###########################################################################
