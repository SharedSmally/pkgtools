#!/usr/bin/perl -w

use strict;
use Cwd;
use File::Basename;

our $DEBUG=1;
our $DENTS=" "x5;

sub getCurrentDir {
	return getcwd;
}
#my $sdir = dirname(dirname($0)); #script homedir

use Common qw( trim writeFile readFile writeArray info infoWriteFile align);  
use CommonXml qw(xmlRoot xmlFile splitXmlText getXmlAttr copy2Attr createDoc);
use MkCommonPkg qw(updateLayout updateDep);

#use XML::LibXML;
use XML::LibXML qw(XML_ELEMENT_NODE);
#######################################################

#######################################################
# sample code for app
sub genAppCodes {
	my ($bdir,$appname)=@_;
	my $file="${bdir}/App_main.cc";  my $s0;  
	  
    unless (-f $file) {
        $s0="
#include <iostream>
int main(int argc, char * argv[]) {
   std::cout << \"hello, ${appname}\" << std::endl;
   return 0;
}";
        infoWriteFile($file, $s0);
    }
    
    #default makefile
    $file="${bdir}/makefile";
    unless (-f $file) {
		$s0="NAME=${appname}\n\ninclude \${DEVTOOLS_HOME}/meta/makeincs/make.app";
        infoWriteFile($file, $s0);        
    }            
}

# sample code for lib/module
sub genModuleCodes {
	my ($bdir,$libname,$modname)=@_;
	
    my $xfile="${bdir}/module.cc"; my $s0;      
    unless (-f $xfile) {
    	$s0  = "
#include <iostream>
#include \"module.h\"
void print${modname}() {
   std::cout << \"hello, module ${modname} in lib ${libname}\" << std::endl;	
}";    	
        infoWriteFile($xfile, $s0);
    }

    $xfile="${bdir}/module.h";      
    unless (-f $xfile) {
        infoWriteFile($xfile, "void print${modname}();");
    }  	
    
    $xfile="${bdir}/makefile";
    $s0="include \${DEVTOOLS_HOME}/meta/makeincs/make.mod";
    infoWriteFile($xfile, $s0);    
}

# sample code for lib
sub genLibCodes {
	my ($bdir,$libname,$version)=@_;
	
    my $xfile="${bdir}/library.cc";  my $s0;    
    unless (-f $xfile) {
    	$s0  = "
#include <iostream>
#include \"library.h\"
void print${libname}() {
   std::cout << \"hello, lib ${libname}\" << std::endl;	
}";    	
        infoWriteFile($xfile, $s0);
    }

    $xfile="${bdir}/library.h";      
    unless (-f $xfile) {
        $s0="void print${libname}();";
        infoWriteFile($xfile, $s0);
    }  	
        
    $xfile="${bdir}/makefile";
	$s0="NAME=${libname}";
	$s0 .= "\n\nVERSION=${version}";
	$s0 .= "\n\ninclude \${DEVTOOLS_HOME}/meta/makeincs/make.lib";
	    
    infoWriteFile($xfile, $s0);
}
#######################################################

#######################################################
# update script descriptor $pdir/src/script
sub updateScript {
    my ($pdir,$fname)=@_;
    my $fullname="${pdir}/script/$fname";
    return if (-f $fullname);
    
    my ($name,$path,$suffix) = fileparse($fullname,qr{\..*});
    
    infoWriteFile ($fullname,"#!/usr/bin/${suffix}\n");
    system("touch $fullname; chmod u+x $fullname"); 
}
# update app descriptor $pdir/src/app/$appname
# main.cc; makefile; makefile
sub updateApp {
    my ($pdir,$name)=@_;
    
    my $hdir="${pdir}/src/appsrc/$name";    
    my $mdir="${hdir}/meta";    
    system("mkdir -p $mdir") unless (-d "$mdir");
                  
	genAppCodes($hdir,$name);      
     
    my $file="${mdir}/app.xml";    
    my $app = xmlRoot($file,"app");   
    $app->setAttribute("name", $name);
    xmlFile($app,$file);        
}

##############################################
# module for library:
#updateModule($hdir, $libnode, $s0);
sub updateModule{
    my ($hdir,$modnode,$libname,$pkgname)=@_;     
    my $modname=$modnode->getAttribute("name");
    my ($type,$sdir)=getSrcTypeDir($modnode);
    my $bdir="${hdir}/${sdir}/${libname}/$modname";
    my $mdir="$bdir/meta";  system("mkdir -p $mdir") unless (-d $mdir);
    
    my $xfile="${mdir}/module.xml";
    info("create $xfile");
    my $mynode=xmlRoot($xfile,"module");
    $mynode->setAttribute("name",$modname);
    $mynode->setAttribute("libname",$libname);
    $mynode->setAttribute("pkgname",$pkgname);
    $mynode->setAttribute("type",$type);
    copy2Attr($modnode,$mynode,"namespace");    
    xmlFile($mynode, $xfile);   
    
    genModuleCodes($bdir,$libname,$modname);  
}

#updateLibMod($hdir, $libnode, \@mods);
sub updateLibMod{
    my ($hdir,$libnode,$mod0)=@_; 
    my ($type,$sdir)=getSrcTypeDir($libnode);
    my @mods=@{$mod0};
    
    my $libname=$libnode->getAttribute("name");
    my $bdir="${hdir}/${sdir}/${libname}";
    my $version=getXmlAttr($libnode,"version","1.0.0");    
    system("mkdir -p $bdir") unless (-d $bdir);
    
    my $xfile="${bdir}/makefile";	
	
    my (@a0,$s0);
    $s0  =  "NAME=${libname}";
	$s0 .=  "\n\nVERSION=${version}";
		    
    push(@a0,"\n\nSUBDIRS = ");
    foreach my $s0 (@mods) { push(@a0,align($s0, 20)); }
    $s0 .= join("\\\n   ", @a0);
    	
	$s0 .= "\n\ninclude \${DEVTOOLS_HOME}/meta/makeincs/make.libmod";
	    
    infoWriteFile($xfile, $s0);
}

#updateLib($hdir, $libnode);
sub updateLib{
    my ($hdir,$libnode,$pkgname)=@_; 
    my ($type, $sdir)=getSrcTypeDir($libnode);
    my $name=$libnode->getAttribute("name");
    my $bdir="${hdir}/${sdir}/${name}";    
    my $mdir="$bdir/meta";  
    system("mkdir -p $mdir") unless (-d $mdir);    
    my $version=getXmlAttr($libnode,"version","1.0.0");
    
    
    my $xfile="${mdir}/${type}.xml";
    info("create $xfile");
    my $mynode=xmlRoot($xfile,$type);
    $mynode->setAttribute("pkgname",$pkgname);
    $mynode->setAttribute("name",$name);
    $mynode->setAttribute("version",$version);
    
    my $libname=getXmlAttr($libnode,"libname",$name);
    $mynode->setAttribute("libname",$libname);
    
    copy2Attr($libnode,$mynode,"namespace");
    xmlFile($mynode, $xfile);    
        
    genLibCodes($bdir,$name,$version);
}

#######################################################
sub getSrcDir {
	my $name = $_[0]->nodeName;
	return  "script"  if ( ($name =~ m/^script$/i) ||  ($name =~ m/^scripts$/i) );
	return  "appsrc"  if ( ($name =~ m/^app$/i)  || ($name =~ m/^application$/i) );
	return  "libsrc"  if ( ($name =~ m/^lib$/i)  || ($name =~ m/^library$/i) );
	return  "dbsrc"   if ( ($name =~ m/^db$/i)   || ($name =~ m/^database$/i) );
	return  "msgsrc"  if ( ($name =~ m/^msg$/i)  || ($name =~ m/^message$/i) );
	return  "nmsgsrc" if ( ($name =~ m/^nmsg$/i) || ($name =~ m/^nmessage$/i) || ($name =~ m/^protocol$/i));
	return  "rptsrc"  if ( ($name =~ m/^rpt$/i)  || ($name =~ m/^report$/i) );
	return  "recsrc"  if ( ($name =~ m/^rec$/i)  || ($name =~ m/^record$/i) );
	return  "svcsrc"  if ( ($name =~ m/^svc$/i)  || ($name =~ m/^service$/i) );
	return  "xmlsrc"  if ( ($name =~ m/^xml$/i)  || ($name =~ m/^xsd$/i) );
	return "libsrc";
}
sub getSrcTypeDir {
	my $s0=getSrcDir($_[0]);
	my $s1=$s0; 	$s1 =~ s/src$//; 
	return ($s1,$s0);	
}

sub getSubdir {
    my @a0;
    push(@a0,"SUBDIRS = ");
    foreach my $s0 (@{$_[0]}) {
    	next if ($s0 eq "script" );
        push(@a0,align($s0, 20));
    }
    return join("\\\n   ", @a0);
}

sub getSubdirMk {
    my $s0 = getSubdir($_[0]);
    $s0 .= "\n\ninclude \${DEVTOOLS_HOME}/meta/makeincs/make.dirs";
	return $s0;
}
sub setRepos {
	my ($root,$pkgname,$version)=@_;
			
    my $repos=$root->getDocumentElement();
    $repos->setAttribute("name",$pkgname);
    $repos->setAttribute("version", $version);
    $repos->setAttribute("system","true");
    $repos->setAttribute("redefine","false");
    $repos->setAttribute("suffix",".h");    
}
sub addReposMod {
	my ($root,$libname,$name,$ns)=@_;
	
	my $mod=$root->createElement("module");
    $mod->setAttribute("libname",$libname);
    $mod->setAttribute("name",${name});	
	
	if ($ns) {
		$mod->setAttribute("namespace",$ns);
		$ns =~ s/\./\//g; $ns .= "/" unless ($ns =~ m/\/$/);
		$mod->setAttribute("prefix",$ns);	
	}
	
	#$mod->setAttribute("suffix",".h");
	$root->getDocumentElement->addChild($mod);
}
sub addReposLib {
	my ($root,$libname,$name,$ns)=@_;
	
	my $mod=$root->createElement("library");
    $mod->setAttribute("libname",$libname);
    $mod->setAttribute("name",${name});	
	
	if ($ns) {
		$mod->setAttribute("namespace",$ns);
		$ns =~ s/\./\//g; $ns .= "/" unless ($ns =~ m/\/$/);
		$mod->setAttribute("prefix",$ns);	
	}
	
	#$mod->setAttribute("suffix",".h");
	$root->getDocumentElement->addChild($mod);
}
sub createTopSrcMk {
	my $pdir=$_[0];
	
	my $file="$pdir/makefile"; 
	my $s0 = "
SUBDIRS = \\
   src

MKDIRS = \\
   bin lib 

include \${DEVTOOLS_HOME}/meta/makeincs/make.srctop	
";
    infoWriteFile($file, $s0); 
		
}
##################################################################
# update package contents based on package node
#  import
#  script
#  application
#
#  ##library
#  library
#  service
#  database
#  message
#  protocol
#  xsd
sub updatePkg {
    my ($pdir,$pkg)=@_;
    updateDep($pdir,$pkg);   # for import node
    
    my $pkgname=$pkg->getAttribute("name");
    my $version=getXmlAttr($pkg,"version","1.0.0");
    my $ns=getXmlAttr($pkg,"namespace",$pkgname);

    my %flags; my @srcmks; my @scps;
    my $repos=createDoc("repository");
    setRepos($repos, $pkgname,$version);

    my $hdir = "$pdir/src";  system("mkdir -p ${hdir}");
    
    foreach my $node ($pkg->childNodes){
        next if ($node->nodeType != XML_ELEMENT_NODE);
        my $nodeName=$node->nodeName;        
        next if ($node->nodeName eq "import") ;
        
        my ($type,$typedir)=getSrcTypeDir($node);
        
        my $sdir="src/${typedir}";  system("mkdir -p ${sdir}");
        
        unless ( exists $flags{$typedir} ) { push(@srcmks, $typedir); $flags{$typedir}=();}
                   
        if ( ($nodeName eq "app") || ($nodeName eq "application") ) {
           foreach my $app (splitXmlText($node)) {
              $app=trim($app); next if (length($app)==0);              
              updateApp($pdir, $app); 
              push(@{$flags{$typedir}},$app);
           }
        } elsif ($node->nodeName eq "script"){
           my $lang=getXmlAttr($node,"lang");
           foreach my $scp (splitXmlText($node)) {
              $scp=trim($scp);  next if (length($scp)==0);
              $scp .= ".${lang}" if ($lang); push(@scps, $scp);
              updateScript($hdir, $scp); 
           }
        } else {  # libraries: src/$nodename/$libname/$modName  (type/name/version/namespace)
           my $libnode=$node->cloneNode(0);
           my $tmpns=getXmlAttr($node,"basespace", $ns);           
           $tmpns .= "." if ($tmpns && ($tmpns !~ m/\.$/));
           
           if ($node->hasAttribute("name")){ #library with modules
               my $name = $node->getAttribute("name");
			   my @mods=();
               #my @mods=splitXmlText($node);
               #foreach my $s0 (@mods) {
               #   	$libnode->setAttribute("name",$s0); 
               #   	my $myns="${tmpns}${s0}"; $myns =~ s/\.$//;
               #   	$libnode->setAttribute("namespace",${myns});                  
               #   	updateModule($hdir, $libnode, $name, $pkgname);                  
               #   	addReposMod($repos,$name, "${name}_$s0",$myns);
               # }
                              
               foreach my $n0  ($node->getChildrenByTagName("module")){
               	my $modns=getXmlAttr($n0,"basespace",$tmpns);
               	$modns .= "." if ($modns && ($modns !~ m/\.$/));
               	foreach my $s0 (splitXmlText($n0)) {
                 	push(@mods,$s0);
                  	$libnode->setAttribute("name",$s0); 
                  	my $myns=getXmlAttr($n0,"subspace",$s0);
                  	$myns="${modns}${myns}"; $myns =~ s/\.$//;

                  	$libnode->setAttribute("namespace",${myns});                  
                  	updateModule($hdir, $libnode, $name,$pkgname);                  
                  	addReposMod($repos,$name, "${name}_$s0",$myns);
               	}
               }
               
               updateLibMod($hdir, $node, \@mods);
               push(@{$flags{$typedir}},$name);
           } else { # lib without modules
               my $libnode=$node->cloneNode(0);
               my $ps0 = getXmlAttr($node, "prefix","");
               foreach my $s0 (splitXmlText($node)) { 
               	  my $psname= "${ps0}${s0}";             	  
                  $libnode->setAttribute("name",$s0);
                  $libnode->setAttribute("libname",$psname);  
                  $libnode->setAttribute("version",$version) unless ($node->hasAttribute("version"));
                  
                  my $myns=getXmlAttr($node,"subspace",$s0);
                  $myns="${tmpns}${myns}"; $myns =~ s/\.$//;
                                    
                  $libnode->setAttribute("namespace",${myns});
                  
                  updateLib($hdir, $libnode,$pkgname);
                  push(@{$flags{$typedir}},$s0);
                  
                  addReposLib($repos,$psname,$s0,$myns);                  
               }
           }
        }
    }
    
    my $file;
    #sdir: sdir: source directories relative to (under) src/:
    while ( my ($sdir, $value) = each(%flags) ) {
        next if ($sdir eq "script");
        $file="$hdir/$sdir/makefile";
        infoWriteFile($file, getSubdirMk(\@{$value}));
    }

    $file="$hdir/makefile";
    infoWriteFile($file, getSubdirMk(\@srcmks));
    
    createTopSrcMk($pdir);
    
    info("create pkg/repos_pkg.xml");
    xmlFile($repos, "pkg/repos_pkg.xml");
}
###########################################################################


###########################################################################
print "[start script]: $0\n";

my $hdir=getCurrentDir();
my $xfile="pkg/layout.xml";
if (-f $xfile) {
    info("update package layout based on $xfile");
    updateLayout($hdir, xmlRoot($xfile));
}
#pkg/build: final package: rpm;deb,tar;...,
$xfile="pkg/package.xml";
if (-f $xfile) {
    info("update package based on $xfile");
    updatePkg($hdir, xmlRoot($xfile));
} else {
    print ("  no $xfile exits\n"); 
}

print "[end script]: $0\n";
###########################################################################
