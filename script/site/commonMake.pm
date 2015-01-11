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
	makeSubdirsMk makeLibMk makeModMk
     );

use common;

###########################################
sub makeSubdirsMk {
	my $mfile=$_[0]; my @subdirs=@{$_[1]};
		
	unshift @subdirs, ('SUBDIRS = ',);
	my @array = @{paddingArray(\@subdirs," " x 3, "\\")};
	
    my @a0 = ("", 
     ".PHONY: subdirs \$(SUBDIRS)","",     
     "subdirs: \$(SUBDIRS)", "",
	 "\$(SUBDIRS):",
	 "\t\$(MAKE) -C \$@");
	
	push(@array, @a0);
	
	writeArray($mfile, \@array);
}
###############################
sub makeLibMk {
	my ($mfile, $name, $version)=@_; 
			
    my @array = ( 
     "name=${name}",     
     "version=${version}",
	 );
		
	writeArray($mfile, \@array);
}

sub makeModMk {
	my ($mfile, $name, $version)=@_; 
			
    my @array = ( 
     "%:inc/%.h %.cc",
     "\t"
	 );
		
	writeArray($mfile, \@array);
}
###########################################