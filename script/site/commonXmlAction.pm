#!/usr/bin/perl -w

#
# commonly used subroutines action for Xml
#
package commonXmlAction;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(
        getListArray
		getXmlDir getXmlPrefix getXmlSuffix getXmlNS
		genXmlDirs genXmlFiles genXmlDirFiles 
		genXmlLink genXmlCopy genXmlCommand 
		genCFile genSimpleCFileCode
	) ;

use common;
use commonXml;
my @SHELL_PATHS=("/bin","/usr/bin","/local/bin","/usr/local/bin");
###########################################
#return a list of files based on pattern:
sub getListArray {
	my $pattern=$_[0];
	my $s0 = system("ls ${pattern}");
	$s0 =~ s/\r/ /g; $s0 =~ s/\n/ /g; $s0 =~ s/\s+/ /g;  
	return split(" ",$s0);
} 
#get directory from base attr: 
sub getXmlDir {
	my $dir = getXmlAttr($_[0],"base",".");
	$dir .= "/" unless ($dir =~ /\/$/);
	return $dir;	
}
#get prefix from prefix attr: 
sub getXmlPrefix {
	my $s0 = getXmlAttr($_[0],"prefix","");	
	return $s0;	
}
#get suffix from suffix attr: 
sub getXmlSuffix {
	my $s0 = getXmlAttr($_[0],"suffix","");	
	return $s0;		
}
#get file modes from mode/shell attr:
# return ($mode,$firstline)
sub getXmlModes {
	my $s0 = getXmlAttr($_[0],"sh","");
	$s0 = getXmlAttr($_[0],"shell","") if (length($s0)==0);
	my $cmd="";
	if (length($s0)>0) {
		foreach my $s1 (@SHELL_PATHS) {
			$s1 .= "/${s0}";
			if (-f "${s1}") { $cmd ="#!"; $cmd .= $s1; last;}	
		}
	}
	
	my $m0 = getXmlAttr($_[0],"mode","");	
	$m0="u+x" if ( (length($s0)>0)&&(length($m0)==0) );
	return ($m0,$cmd);		
}
#get dest directoru from dest attr: 
sub getXmlDestDir {
	my $s0 = getXmlAttr($_[0],"dst","");	
	$s0 = getXmlAttr($_[0],"dest","") if (length($s0)==0);
	$s0 = getXmlAttr($_[0],"destination","") if (length($s0)==0);
	return toDir($s0); 
}
###############################################################
# input: $xnode; create a list of dirs
# <dirs base="" prefix="" suffix="" >list-of-dirs</dirs>
########################################################
sub genXmlDirs {
	my $base=getXmlDir($_[0]);
	my $prefix=getXmlPrefix($_[0]);
	my $suffix=getXmlSuffix($_[0]);
	
	foreach my $name (@{getXmlTextArray($_[0])}) {
		system("mkdir -p ${base}${prefix}${name}${suffix}");
	}		
}
###############################################################
# input: $xnode; create a list of files
# <files base="" prefix="" suffix="" mode="" sh="">list-of-files</dirs>
########################################################
sub genXmlFiles {
	my $base=getXmlDir($_[0]);
	my $prefix=getXmlPrefix($_[0]);
	my $suffix=getXmlSuffix($_[0]);
	
	my ($mode,$cmd)=getXmlModes($_[0]);
	foreach my $name (@{getXmlTextArray($_[0])}) {
		system("mkdir -p ${base}");
		my $fname="${base}${prefix}${name}${suffix}";
		system("echo ${cmd} > ${fname}");
		system("chmod ${mode} ${fname}") if (length($mode)>0);
	}		
}
########################################################
# input: $xnode; create a list of files
# <files base="" prefix="" suffix="" mode="" sh="" file="">list-of-dirs</dirs>
########################################################
sub genXmlDirFiles {
	my $base=getXmlDir($_[0]);
	my $prefix=getXmlPrefix($_[0]);
	my $suffix=getXmlSuffix($_[0]);	
	my ($mode,$cmd)=getXmlModes($_[0]);
	my $fname=getXmlAttr($_[0],"file");
	
	foreach my $name (@{getXmlTextArray($_[0])}) {
		my $dir=toDir("${base}${prefix}${name}${suffix}");
		system("mkdir -p ${dir}");
		my $fname="${dir}${fname}";
		system("echo ${cmd} > ${fname}");
		system("chmod ${mode} ${fname}") if (length($mode)>0);		
	}		
}

########################################################
# input: $xnode; link a list of files
# <link base="" dst="">list-of-patterns</link>
# <copy base="" dst="">list-of-patterns</copy>
########################################################
sub genXmlLink {
	my $base=getXmlDir($_[0]);
	my $dst=getXmlDestDir($_[0]);
	
	foreach my $pattern (@{getXmlTextArray($_[0])}) {
		$pattern ="${dst}${pattern}";
		foreach my $ffname (@{getListArray($pattern)}) {
			my $s1=`basename ${ffname}`; trim($s1);
			system("ln -s ${ffname} ${base}${s1}"); 	
		}
	}		
}
sub genXmlCopy {
	my $base=getXmlDir($_[0]);
	my $dst=getXmlDestDir($_[0]);
	
	foreach my $pattern (@{getXmlTextArray($_[0])}) {
		$pattern ="${dst}${pattern}";
		foreach my $ffname (@{getListArray($pattern)}) {
			system("cp ${ffname} ${base}"); 	
		}
	}	
}
# <command name="">arg/command>
sub genXmlCommand {
	my $name=getXmlAttr($_[0],"name");
	
}
############################

############################
# generate meta/${cfile}.xml from 
#<cfile>list-of-individual-module-ns</cfile>
#<cfile file="filename">list-of-modules-share-ns</cfile>
#
sub genCFile {
	my ($node,$ns, $xfile)=@_;
	my $fname=getXmlAttr($node,"file","");
	
	if (length($fname)>0) {
		my $cfile="meta/${fname}.xml";
		copyTemplateXml($xfile,$cfile,$fname,$ns);
		#add classes
		my $root = getXmlRoot($cfile);
		foreach my $name (@{getXmlTextArray($node)}) {
			if (!hasChild($root,$name)) {
				my $n0 = $root->addNewChild( "", "class");
				$n0->setAttribute("name",$name);
			}
		}
		#print "final xml:".$root->toString();
		writeXml($root,$cfile);	
	} else {
		foreach my $name (@{getXmlTextArray($node)}) {	
			my $cfile="meta/${name}.xml";
			copyTemplateXml($xfile,$cfile,$name,$ns);
			my $root = getXmlRoot($cfile);
			if (!hasChild($root,$name)) {
				my $n0 = $root->addNewChild( "", "class");
				$n0->setAttribute("name",$name);
			}
			writeXml($root,$cfile);	
		}	
	}			
}

#########################################################
# generate *.h/*.cc code from <cfile>***</cfile> 
# return array for header/cc
#
sub  genSimpleCFileCode {
	my ($root, $codemap)=@_;		
	my $name=getXmlFileName($root);
	my @nsstrs = getXmlNSStrs($root); #start/end{; dir(/); prefix(_); ns(::)
	
	my (@h0, @h1, @c0); 
	my $def=$nsstrs[3]; $def .= uc("${name}_H");
	push(@h0, "#ifndef ${def}");
	push(@h0, "#define ${def}\n");

	#inc headers in *.h		
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^inc$/i) || ($name =~ /^h$/i)) {
			push(@h0, @{getXmlIncStrs($node)}); push(@h0, "");			
		} elsif ( ($name =~ /^src$/i) || ($name =~ /^c$/i)) {
			push(@c0, @{getXmlSrcStrs($node)}); push(@c0, "");
		}
	}	
	#foreach $node ($root->getElementsByLocalName('h')) {}
	         
    #namespace starting
    push(@h0, $nsstrs[0]);
    
    #### added
    my ($s1,$s2,$s3,$s4);
	# included in namespace:macro/union/class/struct/typedef/func/cfunc/		
	foreach my $node ($root->childNodes()) {
		next if ($node->nodeType == XML::LibXML::XML_TEXT_NODE);
		next if ($node->nodeType == XML::LibXML::XML_COMMENT_NODE);
		my $name=$node->getName();		
		if ( ($name =~ /^inc$/i) || ($name =~ /^h$/i)) {
			next;			
		} elsif ( ($name =~ /^src$/i) || ($name =~ /^c$/i)) {
			next;
		} elsif ( $name =~ /^macro$/i ) { #macro

		} elsif ( $name =~ /^typedef$/i ) {#typedef

		} elsif ( $name =~ /^decl$/i ) {#prefix declare
						
		} elsif ( $name =~ /^func$/i ) { #func
						
		} elsif ( $name =~ /^cfunc$/i ) { # c functions										
						
		} elsif ( $name =~ /^union$/i ) { # union
						
		} elsif ( $name =~ /^struct$/i ) { # struct
						
		} elsif ( $name =~ /^class$/i ) { # class
			
		} else {
			print "\nunknown node:node name=${name}\n", $node->toString();
		} 
	}       
    #####
    
    #########
    push(@h0, @h1);
    
    #namespace ending
	push(@h0, $nsstrs[1]);
    push(@h0, "\n#endif // end of ${def}\n");
    
    return (\@h0, \@c0);
}
###########################################