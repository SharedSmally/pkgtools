package CommonPkg;

use strict;
use warnings;
use Exporter;

our $DEBUG;

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw(
          updateLayout updateDep 
          getSubdirMk  getScriptMk
          getLibModuleMk getLibMk getModuleMk getAppMk getCfgMk
          getMkFileMod getMkFileLib getMkFileApp
    );

# these are exported by default.
our @EXPORT = qw( getSubdirsMk  );
use XML::LibXML qw(XML_ELEMENT_NODE);
use Common qw( align writeArray $DENTS $SP1 );
use CommonXml qw(xml_true getXmlAttr);

############################################################################
############################################################################
#     common-used subroutines related in package management
############################################################################
sub getAMFlatname {
    my $str=$_[0];
    $str =~ s/-/_/g; $str =~ s/\./_/g;
    return $str;
}
############################################################################
# update package layout based on layout node
# <package>
#    <dirset home="" prefix="" suffix="" mode="">list-of-dirs</dirset>
#    <fileset home="" prefix="" suffix="" mode="">list-of-files</fileset>
#    <dirfileset home="" prefix="" suffix="" mode="" file="">list-of-dirs</dirfileset>
# </package>
# 
sub updateLayout {
    my ($hdir,$pkg)=@_;
    
    my ($mode,$prefix,$suffix,$home, $t0, $t1);
    
    foreach my $node ($pkg->childNodes) {
        next if ($node->nodeType != XML_ELEMENT_NODE);
        
        $home=getXmlAttr($node,"home","");
        $home .= "/" if ($home && ($home !~ m/\/$/));
        $mode=getXmlAttr($node,"mode","");
        $prefix=getXmlAttr($node,"prefix","");
        $suffix=getXmlAttr($node,"suffix","");
        
        if ($node->nodeName eq "fileset") {
			system("mkdir -p ${home}") unless (-d $home);
			foreach $t0  (splitXmlText($node)) {
				$t1="${home}${prefix}${t0}${suffix}";
				system("touch ${t1}") unless (-f $t1);
				system("chmod ${mode} ${t1}") if ( (-f $t1) && $mode );
			}           
        } elsif ($node->nodeName eq "dirset") {
			foreach $t0  (splitXmlText($node)) {
				$t1="${home}${prefix}${t0}${suffix}";
				system("mkdir -p ${t1}") unless (-d $t1);
				system("chmod ${mode} ${t1}") if ( (-f $t1) && $mode );
			}         	
        } elsif ($node->nodeName eq "dirfileset") {
        	my $fname=getXmlAttr($node,"file","");
			foreach $t0  (splitXmlText($node)) {
				$t1="${home}${t0}"; $t1 .= "/" if ($t1 && ($t1 !~ m/\/$/));
				system("mkdir -p ${t1}") unless (-d $t1);
				$t1 .= "${prefix}${t0}${suffix}";
				system("touch ${t1}") unless (-f $t1);
				system("chmod ${mode} ${t1}") if ( (-f $t1) && $mode );
			}        	
        }        
    }
}
#
# make dep sh script based on import: name home
sub updateDep {
    my ($hdir,$pkg)=@_;
    my ($s0,@expts,@deps); 
    
    push(@deps, "#!/bin/bash\n");
    $s0="export PKG_NAME="; $s0 .= $pkg->getAttribute("name");
    push(@deps, $s0);
    push(@deps, "export PKG_HOME=${hdir}");
    
    $s0="
#if [ ! -f \$PKG_HOME/env/swdepot.bashrc ]; then
#    if [ ! -f /swpd/scm/cm/swdepot/PrepareSoftwareDepot.pl ]; then
#        /swdepot/scm/cm/swdepot/PrepareSoftwareDepot.pl  -e \$PKG_HOME/env 
#    else
#        /swpd/scm/cm/swdepot/PrepareSoftwareDepot.pl -e \$PKG_HOME/env 
#    fi
#fi

#if [ -f \$PKG_HOME/env/swdepot.bashrc ]; then
#    echo \"Sourcing \$PKG_HOME/env/swdepot.bashrc\"
#    source \$PKG_HOME/env/swdepot.bashrc
#else
#    echo \"WARN: \$PKG_HOME/env/swdepot.bashrc is missing\"
#    exit 1
#fi\n";
    push(@deps, $s0);
    
    foreach my $node ($pkg->getChildrenByTagName("import")){
        $s0 ="export ";
        $s0 .= uc($node->getAttribute("name"));
        $s0 .= "_HOME=";
        $s0 .= $node->getAttribute("home");
        push(@deps, $s0);
        push(@expts, $node->getAttribute("home"));
    }
    
    if (scalar(@expts)>0) {
       $s0  = "export PATH=\$PATH:"; 
       $s0 .= join("/bin:",@expts); $s0 .= "/bin";
       push(@deps, $s0);
       
       $s0  = "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:"; 
       $s0 .= join("/lib:",@expts); $s0 .= "/lib";
       push(@deps, $s0);
    }
    
    system("mkdir ${hdir}/env/") unless (-d "${hdir}/env/");
    my $shname = "${hdir}/env/build.bashrc";
    writeArray($shname,\@deps);
    
    system("chmod u+x $shname");
}

# SUBDIRS = subdirs \
sub getSubdirMk {
    my @a0;
    push(@a0,"SUBDIRS = ");
    foreach my $s0 (@{$_[0]}) {
        push(@a0,align($s0));
    }
    return join("\\\n   ", @a0);
}
sub getScriptMk {
    my @a0;
    push(@a0,"bin_SCRIPTS = ");
    foreach my $s0 (@{$_[0]}) {
        push(@a0,align($s0));
    }
    return join("\\\n   ", @a0);
}
############################################################################
# create Makefile.am and list of subdirs that will have Makefile.am: for library
# 2 level library: lib <--modules
# -- Top-level Makefile.am : shared library --
# SUBDIRS = sub1 sub2 ...
#  lib_LTLIBRARIES = libtop.la
#  libtop_la_SOURCES =
#  libtop_la_LIBADD = \
#    sub1/libsub1.la \
#    sub2/libsub2.la \
# --sublevel subn/Makefile.am : module --
#  noinst_LTLIBRARIES = libsub1.la
#  libsub1_la_SOURCES = ...
#
## -- Top-level Makefile.am : static library --
# SUBDIRS = sub1 sub2 ...
#  lib_LIBRARIES = libtop.a
#  libtop_a_SOURCES =
#  libtop_a_LIBADD = \
#    sub1/libsub1.a \
#    sub2/libsub2.a \
# --sublevel subn/Makefile.am : module --
#  noinst_LIBRARIES = libsub1.a
#  libsub1_a_SOURCES = ...
#
sub getLibModuleMk {
    my @mods=@{$_[1]};
    
    my $libname="lib".$_[0]->getAttribute("name");
    $libname .= $_[0]->getAttribute("version") if $_[0]->hasAttribute("version");
    
    my $libnameflat=getAMFlatname($libname);
    
    my @mks; my $s0;
    push(@mks, getSubdirMk(\@mods));  # SUBDIRS

    #static library
    if (xml_true($_[0],"static")) {
        push(@mks, "\nlib_LIBRARIES = ${libname}.a");
        push(@mks, "${libnameflat}_a_SOURCES =");
        push(@mks, "${libnameflat}_a_LIBADD = \\");
        foreach $s0 (@mods) {
            push(@mks, "${DENTS}${s0}/lib${s0}.a \\");
        }
    } else {   #shared library
        push(@mks, "\nlib_LTLIBRARIES = ${libname}.la");
        push(@mks, "${libnameflat}_la_SOURCES =");
        push(@mks, "${libnameflat}_la_LIBADD = \\");
        foreach $s0 (@mods) {
            push(@mks, "${DENTS}${s0}/lib${s0}.la \\");
        }
    }
    push(@mks, "\n");

    return join("\n",@mks);
}

####################################################
# create Makefile.am for a module/library.
#  (lib|noinst)_LTLIBRARIES = libsub1.la
#  libsub1_la_SOURCES = ...
#  (lib|noinst)_LIBRARIES = libsub1.a
#  libsub1_a_SOURCES = ...
#
# arg1: mod node with mod/library/pkg name
# arg2: list-of-header files
# arg3: list-of-sources files  
# arg4: list-of-sources test files 
#
# if SDK: directory for headers 
#
sub getModuleMk {
    return myUpdateLibModMk("noinst",$_[0],$_[1],$_[2]);
}
sub getLibMk {
    return myUpdateLibModMk("lib",$_[0],$_[1],$_[2]);
}

sub getAutoMkName {
    my $str=shift;
    $str =~ s/\-/_/g; $str =~ s/\./_/g;
    return $str;
}
sub myUpdateLibModMk {
     my $prefix=$_[0];
     my $name=$_[1]->getAttribute("name");
     my $am_name=getAutoMkName($name);

     my ($srcs,$hds)=("","");

     if ($_[2]) {
         my @srca;
         foreach my $src (@{$_[2]}) {
             push(@srca, align("${src}.h"));
         }
         $hds=${DENTS}.join("\\\n${SP1}${DENTS}",@srca);

         if ($_[3]) {
            @srca=();
            foreach my $src (@{$_[3]}) {
                push(@srca, align("${src}.cc"));
            }
            $srcs=${DENTS}.join("\\\n${DENTS}",@srca);
        }
     }
     my $subdir=$_[1]->getAttribute("subdir");
     
     my $libstr="";
     if (xml_true($_[1],"static")) {
        $libstr="${prefix}_LIBRARIES = lib${name}.a\nlib${am_name}_a_SOURCES = \${mysources}";    
     } else {
        $libstr="${prefix}_LTLIBRARIES = lib${name}.la\nlib${am_name}_la_SOURCES = \${mysources}";
     }
     my $s0 = "
mysources = \\
${srcs}
$libstr

#headers for SDK
if SDK
${SP1}myheaders = \\
${SP1}${hds}

${SP1}myincdir=\${pkgincludedir}/${subdir}
${SP1}myinc_HEADERS = \${myheaders} 
endif

";
    return $s0;
}
####################################################

####################################################
#.PHONY: subdirs $(SUBDIRS)
#
#subdirs: $(SUBDIRS)
#
#$(SUBDIRS):
#    $(MAKE) -C $@ ${MAKECMDGOALS}
#
sub getMkFileSubdirs {
    my @a0;
    push(@a0,"SUBDIRS = ");
    foreach my $s0 (@{$_[0]}) {
        push(@a0,align($s0));
    }
    my $s0=join("\\\n   ", @a0);
    
    my $s1="
${s0}

.PHONY: subdirs \$(SUBDIRS)

subdirs: \$(SUBDIRS)

\$(SUBDIRS):
\t\$(MAKE) -C $@ \${MAKECMDGOALS}
";
    return $s1;
}
#arg1: lib/module node
#arg2: cc files
#arg3: test files
# getMkFileLib($libnode, \@hfiles, \@cfiles, \@tfiles)
sub getMkFileLib {
    my @mods=@{$_[1]};
    
    my $name=$_[0]->getAttribute("name");
    my $version= getXmlAttr($_[0],"version","");
    my @a0;
    
    push(@a0,"SRCS = ");
    foreach my $s0 (@{$_[2]}) {
        push(@a0,align($s0));
    }
    my $s0=join("\\\n   ", @a0);
    
    my $s1="NAME=${name}\n";
    $s1.="VERSION=${version}\n" if ($version);

    $s1.="${s0}\ninclude \${PKG_HOME}/meta/makeincs/lib.make";
    $s1 .= "\ninclude \${PKG_HOME}/meta/makeincs/test.make" if (scalar(@{$_[3]})>0);
    return $s1;
}
# getMkFileMod($libnode, \@mods)
sub getMkFileLibMods {
    my @mods=@{$_[1]};
    
    my $libname="lib".$_[0]->getAttribute("name");
    $libname .= $_[0]->getAttribute("version") if $_[0]->hasAttribute("version");
    
    my @a0;
    push(@a0,"SUBDIRS = ");
    foreach my $s0 (@{$_[0]}) {
        push(@a0,align($s0));
    }
    my $s0=join("\\\n   ", @a0);
    
    my $s1="
${s0}

.PHONY: subdirs \$(SUBDIRS)

subdirs: \$(SUBDIRS)

\$(SUBDIRS):
\t\$(MAKE) -C $@ \${MAKECMDGOALS}
";
    return $s1;
}
# getMkFileMod($libnode, \@hfiles, \@cfiles, \@tfiles)
sub getMkFileApp {
    my @a0;
    push(@a0,"SUBDIRS = ");
    foreach my $s0 (@{$_[0]}) {
        push(@a0,align($s0));
    }
    my $s0=join("\\\n   ", @a0);
    
    my $s1="
${s0}

.PHONY: subdirs \$(SUBDIRS)

subdirs: \$(SUBDIRS)

\$(SUBDIRS):
\t\$(MAKE) -C $@ \${MAKECMDGOALS}
";
    return $s1;
}

####################################################
# getMkFileMod($libnode, \@hfiles, \@cfiles, \@tfiles)
sub getMkFileMod {
    my $s1="";
    $s1="include \${PKG_HOME}/meta/makeincs/module.make\n" if (scalar(@{$_[2]})>0);
    $s1 .= "include \${PKG_HOME}/meta/makeincs/test.make" if (scalar(@{$_[3]})>0);
    return $s1;
}
####################################################

####################################################

####################################################
1
####################################################

