#!/usr/bin/perl -w

use strict;
#
# echo the command-line arguments
#
print "[start script]: $0\n";

print "  Arg num=", $#ARGV, "\n";

for (my $ind=0; $ind<= $#ARGV; $ind++)
{
    print "  Arg[$ind]=$ARGV[$ind]\n";
}

print "[end script]: $0\n";
