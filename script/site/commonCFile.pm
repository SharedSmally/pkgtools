package commonCFile;

use strict;
use warnings;
use Exporter;
use feature qw(switch);

use XML::LibXML;
use XML::LibXML qw(XML_ELEMENT_NODE);

use common qw( trim splitText contains info $BACKUP $SP1);
use commonXml qw( readXmlRoot xmlFile createDoc getXmlAttr 
    hasNamedComponent splitXmlText isXmlTrue isXmlFalse 
    getHFileIncs getCFileIncs);
use commonMD5 qw(parseLabelFiles getLabelStr);

use commonCode qw(
    genDeclCode genUsingCode genDefineCode genTypeDefCode 
    genEnumCode genUnionCode genVarCode genConstCode
    genFunctionCodes genFuncDefCode
); 

use commonClass qw(genClassCode);
#use commonUTest qw(genUnitTest);

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw(genCFileCode );

# these are exported by default.
our @EXPORT = qw( genCFileCode );

use Cwd;
my $mydir = getcwd;
my $suf=".cc";
my $E0_NUM=3;
####################################################
# common-used subroutines related to cfile node
####################################################
############################################################################
#  genCFileCode($cfilexml)  
############################################################################
sub genCFileCode { 
   my $cnode=$_[0];
   my $fname=$cnode->getAttribute("name");
   my $cfile="${fname}${suf}";
   my $hfile="inc/${fname}.h";           
   my $clsns=getXmlAttr($cnode,"namespace", "");
       
   # parse existing code from *.cc and *.h files 
   my @labelFiles=($hfile, $cfile);
   my %codes = %{parseLabelFiles( (\@labelFiles) )}; 

   my (@ha, @iha, @ca, $t1, $t2, $flag); $flag=0;
   
   my $ext = isXmlTrue($cnode, "ext");
   # pre*code: extra signature for cfile/class: within namespace
   if ($ext) {
   		push(@ha,getLabelStr("pre_${fname}.h", \%codes));
   		push(@ca,getLabelStr("pre_${fname}${suf}", \%codes));
   }
   
   foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE); 
           
      if ($t1->nodeName eq "decl")    { 
      	push(@ha, @{genDeclCode($t1)});    	$flag=1; next;
      }
      
      if ($t1->nodeName eq "using")   { 
      	push(@ha, @{genUsingCode($t1)});   	$flag=1; next;
      }
      if ($t1->nodeName eq "define")  { 
      	push(@ha, genDefineCode($t1));     	$flag=1; next;      	
      }
      
      if ($t1->nodeName eq "typedef") {
      	push(@ha, genTypeDefCode($t1));    	$flag=1; next;
      }
      
      if ($t1->nodeName eq "deffn")   { 
      	 push(@ha, genFuncDefCode($t1));   	 $flag=1; next;      	
      }
      if ($t1->nodeName eq "funcdef") { 
      	push(@ha, genFuncDefCode($t1));    	$flag=1; next;
      }
      
      if ($t1->nodeName eq "enum")    { 
      	push(@ha, genEnumCode($t1));      	$flag=1; next;
      }
      if ($t1->nodeName eq "union")   { 
      	push(@ha, genUnionCode($t1));      	$flag=1; next;
      } 
      
      if ($t1->nodeName eq "var")     { 
      	my ($x1,$x2)=genVarCode($t1);   push(@ha,$x1);   
      	push(@ca,$x2) if ($x2);      	$flag=1; next;
      } 
      
      if ($t1->nodeName eq "const")   {
      	 my ($x1,$x2)=genConstCode($t1); push(@ha,$x1); 
      	 push(@ca,$x2) if ($x2);      	 $flag=1; next;
      } 
      
      if ( ($t1->nodeName eq "cfunc") || ($t1->nodeName eq "cfunction") )  { 
         my ($havar, $cavar, $ihavar) = genFunctionCodes($t1, "", \%codes);
         if ($havar)  {  push(@ha, "extern \"C\" { "); push(@ha, $havar.";"); push(@ha, "} ") ; $flag=1;}; 
         if ($cavar)  {  push(@ca, "extern \"C\" { "); push(@ca, $cavar); push(@ca, "} ") ; }
         if ($ihavar) {  push(@iha,"extern \"C\" { "); push(@iha,$ihavar); push(@iha, "} ") ; }
         next;         
      }  
      
      if ( ($t1->nodeName eq "func") || ($t1->nodeName eq "function") )  {
         my ($havar, $cavar, $sig, $mdsig, $ihavar) = genFunctionCodes($t1, "", \%codes);
         if ($havar)  {  push(@ha, $havar.";\n"); $flag=1;}; 
         if ($cavar)  {  push(@ca, $cavar);  }
         if ($ihavar) {  push(@iha,$ihavar); }
         next;
      } 
           
      if ($t1->nodeName eq "class") {
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes); #, $interfaces);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { 
         	push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; 
         } 
         push(@ca, @{$cavar}) if (@{$cavar});   
         push(@iha, @{$ihavar}) if (@{$ihavar});
         next;  
      }
      
      if ($t1->nodeName eq "struct") {
         $t1->setAttribute("struct","true"); 
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes); #, $interfaces);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { 
         	push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; 
         } 
         push(@ca, @{$cavar}) if (@{$cavar});   
         push(@iha, @{$ihavar}) if (@{$ihavar});  
         next;
      } 
      
      if ($t1->nodeName eq "interface") { 
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes); #, $interfaces);
         if ($havar) { 
         	push(@ha, "") if ($flag);    
         	push(@ha, @{$havar});  $flag=0; 
         } 
         push(@ca, @{$cavar}) if (@{$cavar});   
         push(@iha, @{$ihavar}) if (@{$ihavar});
         next;  
      }
      
      if ($t1->nodeName eq "text"){ 
         my $txt=trim($t1->textContent); $txt .="\n" if ($txt);
         if (isXmlTrue($t1,"c") || isXmlTrue($t1,"c")) { push(@ca, $txt); }
         else { push(@ha, $txt); }
      }        
   }
   
   # pre*code: extra signature for cfile/class: within namespace
   if ($ext) {
   		push(@ha, getLabelStr("post_${fname}.h", \%codes));
   		push(@ca, getLabelStr("post_${fname}${suf}", \%codes));
   }

   my $nca = @ca; my $nha = @ha;   
   # get header/namespace & save *.h file
   if ($nha>1) {   
   		my @hincs = getHFileIncs($cnode);   		
   		unshift @ha, @{$hincs[0]};   
   		push @ha, @iha;  
   		push @ha, @{$hincs[1]};
   }
   
   # get header/namespace & save *.cc file   
   if ($nca>1) {  
   		my @cincs = getCFileIncs($cnode);
   		unshift @ca, @{$cincs[0]};
   		push @ca, @{$cincs[1]}; 
   }
         
   # testing cases for cfile node
   my $utests; # = genUnitTest($cnodebak);
   
   return (\@ha, \@ca, $utests);
}

############################################################################

############################################################################

############################################################################
