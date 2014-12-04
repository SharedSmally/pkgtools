#!/usr/bin/perl -w

#
# generate meta/*.xml from meta/class.cfg:
# namespace=a.b.c
# cfile=class1 class2 class3
# cfiles=classF1 classF2 classF3
# ......
#

use strict;
use warnings;

#require xxx;
#location of modules: using PERL5LIB or BEGIN 
#export PERL5LIB=/home/foobar/code
#BEGIN { push @INC, '/cygdrive/c/Users/Guest/git/pkgtools/script' }
#use A::B::C will search A/B/C.pm
use common;

my $SP3=common::SPACES;
#my $SP3=common::${OUR_SP4};

############################################
# input: base_filename, ns
# return ($filename, cfile_xml)
sub getNSXml {
	my ($filename, $ns)=@_;
	
	my $r0="./meta/${filename}.xml";	
	my $r1="<cfile file=\"${filename}\"";
	$r1 .= " namespace=\"${ns}\"" if ($ns); 
	$r1 .= ">";			
	
	return ($r0,$r1);	
}

sub generateXmls {	
	my $ns = $_[0];
	my @args = @{$_[1]};
	my ($filename, $nsstr)=getNSXml($args[0], $ns);

	if (-f $filename)  { print " cfile ${filename} already exists\n"; return;}
			
	my @array;
	push(@array, $nsstr);	
	foreach my $arg (@args){
		push(@array, "${SP3}<class name=\"${arg}\">");
		push(@array, "${SP3}</class>");
	}
	push(@array, "</cfile>");

	writeArray($filename, \@array);	
}
sub generateXml {
	my ($ns,$arg) = @_;		
	my ($filename, $nsstr)=getNSXml($arg, $ns);
	
	if (-f $filename)  { print " cfile ${filename} already exists\n"; return;}
		
	my @array;	
	push(@array, $nsstr);	
	push(@array, "${SP3}<class name=\"${arg}\">");
	push(@array, "${SP3}</class>");
	push(@array, "</cfile>");

	writeArray(${filename}, \@array);
}

######################################################
my ($ns,$name,$val,@vals); 
my $filename = 'meta/class.cfg';

my $num=0;

foreach my $line (@{readArray($filename)})  {
	#chomp $line;
	$num++;	 $line=trim($line); 
	next if ( (length($line)<=0) || ($line =~ /^\s+/) || ($line =~ /^#/) );	
	my @vs = split(/\s*=\s*/, $line);
	next if (length(@vs)<=0);
	$name=$vs[0]; next if (length(@vs)<=0); 
	if ( ($name =~ m/^ns$/i) || ($name =~ m/^namespace$/i) ) {
		$ns=trim($vs[1]); next;
	}
	 
	$val=$vs[1];	
	#$val =~ s/\s*;\s*/\s/g; not work: unrecognized \s
	$val =~ s/ *, */ /g;
	$val =~ s/ *; */ /g;
	$val =~ s/ +/ /g;
	@vals=split(/\s/,$val);
	
	if ($name =~ /^cfile$/) {
		generateXmls($ns, \@vals);
	} elsif ($name =~ /^cfiles$/) {
		foreach my $arg (@vals) {
			generateXml($ns, $arg);	
		}		
	}  else {
		print "unknown header:", ${name},"@",${num},":${line}\n";
	}
}
