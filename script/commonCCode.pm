#!/usr/bin/perl -w

#
# commonly used subroutines for Xml
#
package commonCCode;
  
use strict;
use warnings;
use base 'Exporter';

use XML::LibXML;

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(genMacroCode genTypedefCode getDeclCode) ;

use common;
use commonXml;
use commonType;
###########################################
sub genMacroCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
sub genTypedefCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
sub genDeclCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
sub genFuncCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
sub genCfuncCode {
	my $node=$_[0];
	my (@ha, @hs, @ca);
	
	return (\@ha, \@hs, \@ca);
}
###########################################