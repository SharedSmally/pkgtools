#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x5;

my $dir = getcwd;
my $sdir = dirname(dirname($0)); #script homedir

use Common qw(info infoWriteFile);
use CommonXml qw( xmlRoot );
use CommonImpt qw( getImports );
use CommonCFile qw( updateCFileMeta getInterfaces genCFileCode);
use MkCommonPkg qw( getLibMk getTestMk);

sub createLibMk{
    my ($modnode) = @_;
    
	my $xfile="makefile";
	infoWriteFile($xfile, getLibMk($modnode));
	
	if (-d "test") {
		$xfile="test/makefile";
		infoWriteFile($xfile, getTestMk($modnode));
	}
}

sub updateModule {
    my $xfile=$_[0];
    my $hdir = getcwd;
    
    info("update module based on $xfile");
    unless (-f $xfile) { print ("  no $xfile exits\n"); return; }

    my $modnode = xmlRoot($xfile);
    my $t1 = updateCFileMeta($modnode); # list-of-files
    
    my $impts = getImports($modnode);   # import mapping: name->import
    my $intfs = getInterfaces($t1, $modnode); # interfaces mapping: name->interface

    my (@hfiles, @cfiles,@tfiles);
    foreach my $t2 (@{$t1}) { # for each cfiles
        my $t3="meta/${t2}.xml";
        my ($hasC, $utests) = genCFileCode($modnode,$t3,$impts,$intfs); 
        push(@hfiles,$t2);
        push(@cfiles,$t2) if ($hasC);  
        push(@tfiles,$utests) if ($utests);
    }

    createLibMk($modnode, scalar(@tfiles) );     
}
###########################################################################
print "[start script]: $0\n";
 
system("mkdir test") unless (-d "test");
if ($#ARGV==-1) { updateModule("./meta/lib.xml"); }
else {  foreach my $arg (@ARGV) { updateModule($arg);} }

print "[end script]: $0\n";
###########################################################################
