#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x5;

use Common qw(info infoWriteFile);
use CommonXml qw( xmlRoot );
use CommonImpt qw( getImports );
use CommonCFile qw( updateCFileMeta getInterfaces genCFileCode);
use MkCommonPkg qw( getModMk getTestMk);
###########################################################################
###########################################################################
# update meta/module.xml and meta/*.xml
sub updateModule {
    my $file=$_[0];
    my $xfile="meta/module.xml";
    my $hdir = getcwd;
    
    return if ($file eq $xfile);
    unless (-f $xfile) { print ("  no $xfile exits\n"); return; }

    my $modnode = xmlRoot($xfile);
    my $t0=$file; $t0 =~ s/^meta\///; $t0 =~ s/\.xml$//;
    my @t1=($t0);      
    my $impts = getImports($modnode);   # import mapping: name->import
    my $intfs = getInterfaces(\@t1, $modnode); # interfaces mapping: name->interface

	genCFileCode($modnode,$file,$impts,$intfs);
}
###########################################################################
print "[start script]: $0\n";
 
if ($#ARGV==-1) { print "Usage: pkg_cfile.pl \${cfile.xml}"; exit 1; }
else {  foreach my $arg (@ARGV) { updateModule($arg);} }

print "[end script]: $0\n";
###########################################################################
