#!/usr/bin/perl -w

#
# commonly used subroutines to generate makefile
#
package commonMake;
  
use strict;
use warnings;
use base 'Exporter';

#our @ISA = qw(Exporter);
#################################
our @EXPORT = qw(
	makeSubdirs  
     );

use common;

###########################################
sub makeSubdirs {
	my $mfile=$_[0]; my @subdirs=@{$_[1]};
	my @array;
	
	push(@array, "")
	
	foreach $s0 (@subdirs) {
		
	}
	
	  
	writeArray($mfile,@array);
}
###############################

###########################################