#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x5;

my $dir = getcwd;
my $sdir = dirname(dirname($0)); #script homedir

use Common qw( trim writeFile readFile writeArray info);  # import listed items
use CommonXml qw(xmlRoot xmlFile splitXmlText getXmlAttr copy2Attr );
use CommonPkg qw(updateLayout updateDep  getScriptMk getLibMk getModuleMk getLibModuleMk getSubdirMk );

#use XML::LibXML;
use XML::LibXML qw(XML_ELEMENT_NODE);

# return package home dir based on $pkg_home_dir/meta/pkg/package.xml
sub getPackageDir {
   return dirname(dirname($dir));;
}

#
sub updateModuleMk{
    my $modnode=$_[0]; 
    my @mks;
    
    #writeArray("./Makefile.am", \@mks);
}
sub updateCFile{
    
    
    
}

# library node: namespace; subdir
## <library name="" version="" category="" namespace="" subdir="">
#   <import>imported-header-file</import>*
#   <incpath></incpath>
#   <libpath></libpath>
#   <flag name="" value="" target="" append="true|false"/>
#   <cflag name="" value="" append="true|false">flag-list</cflag>
#   <cxxflag name="" value="" append="true|false"/>
#   <cppflag name="" value="" append="true|false"/>
#
#   <cfile> list of classes </cfile>*  each has its own *.cc and *.h
#   <cfile file=""> list of classes </cfile>: share the same *.cc and *.h
#   <interface> list of classes </cfile>*  each has its own *.cc and *.h
#   <interface file=""> list of classes </cfile>: share the same *.cc and *.h
# </library>
sub updateModule{
    my ($hdir,$modnode)=@_; 
    my $type=$modnode->nodeName;
    my $ns=$modnode->getAttribute("namespace");
    my $subdir=$modnode->getAttribute("subdir");

    system("mkdir -p ./meta") unless (-d "./meta");
    
    my (@hfiles, @cfiles, @tfiles);
    foreach my $cnode ($modnode->getChildrenByTagName("cfile")) {
       if ($cnode->hasAttribute("name")) { # one node with multiple classes
          
       }else {
          
       }
    }

    #create header/class files for each one;
    foreach my $file (@hfiles) {
        my $xfile="./meta/${file}.xml";
        my $res = updateCFile(xmlRoot($file));
        if ($res==1) {push(@cfiles, $file);}
        elsif ($res==2) {push(@tfiles, $file);}
        elsif ($res==3) {push(@tfiles, $file); push(@cfiles, $file);}
    }
    
    updateModuleMk($modnode, \@hfiles, @cfiles, @tfiles);
}


###########################################################################
print "[start script]: $0\n";

my $hdir=getPackageDir();
my $xfile="./library.xml";
if (-f $xfile) {
    info("update module based on $xfile");
    updateLibrary($hdir, xmlRoot($xfile));
} else {
    print ("  no ./library.xml exits\n"); 
}

print "[end script]: $0\n";
###########################################################################
