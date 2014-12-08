#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonClass;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(genUnionCode genClassCode) ;

use common;
use commonXml;
use commonType;
use commonFunc;
###########################################
sub genUnionCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

####  generate class related code
# <class/struct name="" parent="" template="">
#    <parent></parent>*
#    <template></template>*
#    <friend></friend>*   #class/function    
#    <deconstructor access="public|priv|prot|none"/>
#    <public|protected|private>
#       <typedef></typedef>*
#       <constructor></constructor>*
#       <field></field>*
#       <method></method>*
#    </public|protected|private>
# <class/struct>
sub genClassCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	my ($t1,$t2,$t3,$t4,$t5,$t6);
	
	#template
	
	#parent
	
	#friend class
	
	#method
	
	return (\@ha, \@hs, \@ca);
}
###########################################