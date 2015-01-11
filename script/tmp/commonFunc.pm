#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonFunc;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(genFuncCode genCfuncCode) ;

use common;
use commonXml;
use commonType;
###########################################
# for method, including className
# <function name="" return="" template="" impl="">
#    <ret></ret>
#    <template></template>*
#    <partial></partial>*
#    <arg/>*
#    <impl></impl>*
# <function>
sub genFuncCode {
	my $node=$_[0];
	my $clsinfo=$_[1]; #class related info
	
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

#########################
#<cfunction>
#   <function>*
#</cfunction>
sub genCfuncCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	my ($t1,$t2,$t3,$t4,$t5);
	
	push(@ha, "extern \"c\" {"); push(@ca, "extern \"c\" {");
	foreach my $mynode ($node->childNodes()) {
		my $name=$node->getName();
		if ( ($name =~ /^function$/i) || ($name =~ /^f$/i) || ($name =~ /^func/i) ) { 
			my ($t1,$t2,$t3)=genFuncCode($mynode);
			push(@ha, @{$t1});
			push(@hs, @{$t2});
			push(@ca, @{$t3});
		} else {
			print "unknown node in cfunction:\n", $mynode->toString(1);
		}
	}
	
	push(@ha, "}");  push(@ca, "}");
	return (\@ha, \@hs, \@ca);
}
###########################################