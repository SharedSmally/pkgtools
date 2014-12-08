#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonType;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(genArgCode genTypeCode genTemplateCode) ;

use common;
use commonXml;
###########################################
sub genArgCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

sub genTypeCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}

########## generate template str for class/function
sub genTemplateCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
###########################################