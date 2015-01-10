#!/usr/bin/perl -w

#
# create dirs and files for CA
#
sub genCADir {
	# Specify directory name on command line or use default.
	my $ca_root_dir = $_[0];

	# Create root directory for CA files.
	if(not -d $ca_root_dir) {
	    mkdir $ca_root_dir, 0700 or die "Can't create '$ca_root_dir' directory: $!.";
	}

	# Create directory for private-key files.
	if(not -d "$ca_root_dir/private") {
	    mkdir "$ca_root_dir/private", 0700 or die "Can't create '$ca_root_dir/private': $!";
	}	

	# Create directory for certificate files.
	if(not -d "$ca_root_dir/certs") {
	    mkdir "$ca_root_dir/certs", 0700 or die "Can't create '$ca_root_dir/certs': $!";
	}
	if(not -d "$ca_root_dir/crl") {
	    mkdir "$ca_root_dir/crl", 0700 or die "Can't create '$ca_root_dir/crl': $!";
	}
	
	# Create directory for conf files.
	if(not -d "$ca_root_dir/conf") {
	    mkdir "$ca_root_dir/conf", 0700 or die "Can't create '$ca_root_dir/conf': $!";
	}	

	# Initialize serial if it isn't already created.
	if(not -f "$ca_root_dir/conf/serial") {
    	system("echo '01' > $ca_root_dir/conf/serial") ;
    	#open SERIAL, ">$ca_root_dir/conf/serial" or die "Can't create conf/serial: $!";
    	#print SERIAL "01\n"; close SERIAL;
	}

	# Create index file if not existant.
	if(not -f "$ca_root_dir/conf/index.txt") {
	    system("touch $ca_root_dir/conf/index.txt") ;
	    #open INDEX, ">$ca_root_dir/conf/index.txt"	or die "Can't create conf/index.txt: $!"; close INDEX;
	} 

	# Initialize random number file.
	if(not -f "$ca_root_dir/conf/rand") {
    	open RAND, ">$ca_root_dir/conf/rand" or die "Can't create randfile: $!";
    	my($r) = int(rand(90)+10);
    	print RAND "$r\n";
    	close RAND;
	}
}

#
# generate openssl.cnf for CA
#
sub genCAConf {
	my ($ca_dir,$ca_name)=@_;
	my $s0 =`dirname $0`; $s0 =~ s/\s+$//;
	#print "base dir=$s0\n";
	my $cnf="${ca_dir}/conf/openssl.cnf";
	my $tfile="tfile";
	my $cmd="cp ${s0}/openssl.cnf ${cnf}";	system($cmd);
	$cmd="sed \"s/%ca_dir%/${ca_dir}/g\" \"${cnf}\" > $tfile && mv $tfile \"${cnf}\"";
	print "cmd=\n${cmd}\n";
	system($cmd);
	
}

sub printUsage {
	#print "command $0\n";
	#print "command dir:", `dirname $0`;
	#my $s0 =`dirname $0`;
	my $s0 = `basename $0`; $s0 =~ s/\s+$//;
	print "Usage: $s0 [-h [ca_name [ca_root_dir] ] ]\n";
}
########################
if ( (@ARGV==1) && ( ($ARGV[0] =~ /^-h$/i) || ($ARGV[0] =~ /^--help$/i) ) ) {
	printUsage(); exit 0;
}

my $caname = (@ARGV<1) ? "ca" : $ARGV[0];
my $cadir= (@ARGV<2) ? "ca" : $ARGV[1];

 genCADir($cadir);
 genCAConf($cadir,$caname); 
 genCA();

# The procedure for OpenSSL certificates
# 1. Create keypair (RSA,DSA,EC): 
#   openssl genrsa -des3 -out root-ca.key 1024 
# 2a: Use the key to sign itself: 
#   openssl req -new -x509 -days 3650 -key root-ca.key -out root-ca.crt -config openssl.cnf 
# 2b. Create certificate signing request for generated key-pair in 1:
#   openssl req -new -days 1095 -key signing-ca-1.key -out signing-ca-1.csr -config openssl.cnf 
# 2c. Create a key and a certificate signing request in one step:
#   openssl req -newkey rsa:1024 -keyout zmiller.key -config openssl.cnf -out zmiller.req
#
# 3. Sign the certificate request: 
#   openssl ca -config openssl.cnf -out zmiller.crt -infiles zmiller.req
#   using the "-name" argument to specify the section in the altered openssl.cnf file
#   openssl ca -config openssl.cnf -name CA_root -extensions v3_ca -out signing-ca-1.crt -infiles signing-ca-1.csr 
 
# 4.Print the generated certificate 
#   openssl x509 -noout -text -in root-ca.crt 
#