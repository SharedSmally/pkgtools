package CommonCMsg;
#IPC message

use strict;
use warnings;
use Exporter;

use XML::LibXML;
use XML::LibXML qw(XML_ELEMENT_NODE);

use Common qw( trim splitText contains info $BACKUP $SP1);
use CommonXml qw( xmlRoot xmlFile createDoc getXmlAttr getPkgHome getIncludeHome 
    hasNamedComponent splitXmlText xml_true xml_false);
use CommonImpt qw(getHFileImportStr getCFileImportStr getCImportStr);
use CommonMD5 qw(parseLabelFiles getLabelStr);

use CommonDefine qw(
    genDeclCode genUsingCode genDefineCode genTypeDefCode 
    genEnumCode genUnionCode genVarCode genConstCode
    genFunctionCodes genFuncDefCode
); 

use CommonClass qw(genClassCode );
use CommonUTest qw(genUnitTest);
use CommonCHCode qw(saveHCode saveCCCode);

#define a module
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( 
     updateCMsgMeta  genCMsgCode
 );

# these are exported by default.
our @EXPORT = qw( genCMsgCode );

use Cwd;
my $mydir = getcwd;
####################################################
# common-used subroutines related to cfile node
####################################################
############################################################################
#  genCFileCode($mod,$cfilexml,$impts,$intfs)  
############################################################################
sub genCMsgCode { # mod; xmlfile; impts;
   my $mod=$_[0];      my $xmlfile=$_[1];  
   my %impts=%{$_[2]}; 

   print "${SP1}***parse cfile $xmlfile:\n";
   my $cnode=xmlRoot($xmlfile);
   my $fname=$cnode->getAttribute("name");
   my $E0_NUM=3;
   
   my $clsns=getXmlAttr($mod,"namespace", "");
   my $suf=getXmlAttr($cnode,"suffix","cc");
   $suf=".${suf}" unless ($suf =~ /^\./);
    
   # parse existing *.cc and *.h files 
   my @labelFiles=("${fname}.h","${fname}${suf}");
   my %codes = %{parseLabelFiles( (\@labelFiles) )}; 

   my (@ha, @iha, @ca, $t1, $t2, $flag); $flag=0;
   
   # pre*code
     ###########  extra signature for class.
   if (xml_true($cnode,"ext") || xml_true($cnode, "extension") ) {
      push(@ha,getLabelStr("pre_${fname}.h", \%codes));
      push(@ca,getLabelStr("pre_${fname}${suf}", \%codes));
   }
   
   if (xml_true($cnode,"extC")) {  push(@ha, "extern \"C\" { "); push(@ca, "extern \"C\" { "); }

   foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE); 
      if ($t1->nodeName eq "decl")       { $t2=genDeclCode($t1); push(@ha, @{$t2}); $flag=1;}
      elsif ($t1->nodeName eq "using")   { $t2=genUsingCode($t1); push(@ha, @{$t2}); $flag=1;}
      elsif ($t1->nodeName eq "define")  { push(@ha, genDefineCode($t1));  $flag=1;}
      elsif ($t1->nodeName eq "typedef") { push(@ha, genTypeDefCode($t1)); $flag=1;}
      elsif ($t1->nodeName eq "deffn")   { push(@ha, genFuncDefCode($t1)); $flag=1;}
      elsif ($t1->nodeName eq "funcdef") { push(@ha, genFuncDefCode($t1)); $flag=1;}
      elsif ($t1->nodeName eq "enum")    { push(@ha, genEnumCode($t1)); $flag=1;}
      elsif ($t1->nodeName eq "union")   { push(@ha, genUnionCode($t1)); $flag=1;} 
      elsif ($t1->nodeName eq "var")     { my ($x1,$x2)=genVarCode($t1);   push(@ha,$x1); push(@ca,$x2) if ($x2); $flag=1;} 
      elsif ($t1->nodeName eq "const")   { my ($x1,$x2)=genConstCode($t1); push(@ha,$x1); push(@ca,$x2) if ($x2); $flag=1;}  #
      elsif ($t1->nodeName eq "cfunc")   { 
         my ($havar, $cavar, $ihavar) = genFunctionCodes($t1, "", \%codes);
         if ($havar)  {  push(@ha, $havar.";"); $flag=1;}; 
         if ($cavar)  {  push(@ca, $cavar); }
         if ($ihavar) {  push(@iha,$ihavar);}
      }  
      elsif ($t1->nodeName eq "function") {
         my ($havar, $cavar, $sig, $mdsig, $ihavar) = genFunctionCodes($t1, "", \%codes);
         if (xml_true($t1,"c") || xml_true($t1,"extC")) {
            if ($havar)  {  push(@ha, "extern \"C\" { "); push(@ha, $havar.";"); push(@ha, "} ") ; $flag=1;}; 
            if ($cavar)  {  push(@ca, "extern \"C\" { "); push(@ca, $cavar); push(@ca, "} ") ; }
            if ($ihavar) {  push(@iha,"extern \"C\" { "); push(@iha,$ihavar); push(@iha, "} ") ; }
         } else {
            if ($havar)  {  push(@ha, $havar.";"); $flag=1;}; 
            if ($cavar)  {  push(@ca, $cavar);  }
            if ($ihavar) {  push(@iha,$ihavar);  }
         }
      } elsif ( ($t1->nodeName eq "message") || ($t1->nodeName eq "msg") ) {
         my ($havar, $cavar, $ihavar) = genMsgCode($t1, \%codes);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; } 
         push(@ca, @{$cavar}) if (scalar(@{$cavar})>0);   push(@iha, @{$ihavar}) if (scalar(@{$ihavar})>0);  
      } elsif ($t1->nodeName eq "struct") {
         $t1->setAttribute("struct","true"); 
         my ($havar, $cavar, $ihavar) = genMsgCode($t1, \%codes);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; } 
         push(@ca, @{$cavar}) if (scalar(@{$cavar})>0);   push(@iha, @{$ihavar}) if (scalar(@{$ihavar})>0);  
      }
   }
   my $imptname=getXmlAttr($mod,"libname",""); 
   $imptname .="_" if ($imptname); $imptname .= getXmlAttr($mod,"name","");
   unless (exists $impts{$imptname} ) {
     $imptname = $mod->getAttribute("pkgname")."::${imptname}";
   }
   my $himpt = getHFileImportStr( $cnode, $_[2], $imptname);
   my $cimpt = getCFileImportStr( $cnode, $_[2], $imptname); 
   $cimpt .="\n" if ($cimpt);
   #print "cfile cnode:\n", $cnode->toString(1), "\n";
   
   if (exists $impts{$imptname} ) {
        $cimpt .= getCImportStr($fname,$impts{$imptname}); 
        $cimpt .="\n";
   }

   if (xml_true($cnode,"extC")) { push(@ha, "} ");  push(@ca, "} "); }

   # post*code
   if (xml_true($cnode,"ext") || xml_true($cnode, "extension") ) {
      push(@ha, getLabelStr("post_${fname}.h", \%codes));
      push(@ca, getLabelStr("post_${fname}${suf}", \%codes));
   }
   
   saveHCode($fname, $clsns, $himpt, \@ha, $BACKUP, \@iha) if (scalar(@ha)>0);
   
   my $hasC=0;
   if (xml_true($cnode,"extC")) {
      if (scalar(@ca)>2) { saveCCCode($fname, $clsns, $cimpt, \@ca, $BACKUP) ; $hasC=1; }
   } else {
      if (scalar(@ca)>0) { saveCCCode($fname, $clsns, $cimpt, \@ca, $BACKUP) ; $hasC=1; }
   }
   
   # link *.h header file.
   my $hdir=getIncludeHome($mod); 
   system("mkdir -p $hdir") unless (-d $hdir) ;
   info(" link ${fname}.h to ${hdir}${fname}.h");
   system("rm -rf ${hdir}${fname}.h; ln -s $mydir/${fname}.h ${hdir}${fname}.h"); 
   
   # testing cases for cfile node
   my $utests = genUnitTest($cnode);
   
   return ($hasC, $utests);
}

############################################################################

############################################################################
# update meta/*.xml based on library.xml/module.xml:
# <module name="" category="" namespace="" subdir="">
#    <cfile> list of classes </cfile>*  each has its own *.cc and *.h
#    <cfile file=""> list of classes </cfile>: share the same *.cc and *.h
# </module> 
############################################################################
my @flag_nodes=("import","impt_interface","flag","incpath", "libpath","library");
sub updateCMsgMeta {
   my $node=$_[0]; 
   
   system("mkdir -p ./meta") unless (-d "./meta");

   my ($t1,$t2, @hfiles); 
   #foreach $t1 ($node->getChildrenByTagName("cfile")) {
   foreach $t1 ($node->childNodes) {
     next if ($t1->nodeType != XML_ELEMENT_NODE);
     next if (contains($t1->nodeName,\@flag_nodes));
     
     if ($t1->hasAttribute("file")) { 
          $t2=trim($t1->getAttribute("file")); push(@hfiles,$t2);
          updateMetaXml($node, $t2, $t1->textContent, $t1->nodeName);
     } else { 
        foreach $t2 (splitXmlText($t1)) {
           $t2=trim($t2); next unless ($t2);  push(@hfiles, $t2);
           updateMetaXml($node, $t2, $t2, $t1->nodeName); 
        }
     }
   } 
   
   #links to import_std.xml
   my $t0=getPkgHome($node);
   $t1="${t0}/meta/pkg/repos_pkg.xml"; $t2="meta/import_pkg.xml";
   if (-f $t1) {  info("link $t1 to $t2"); system("rm -rf ${t2}; ln -s ${t1} ${t2}"); } 

   $t1="${t0}/meta/pkg/import_std.xml"; $t2="meta/import_std.xml";
   if (-f $t1) {  info("link $t1 to $t2"); system("rm -rf ${t2}; ln -s ${t1} ${t2}"); } 

   return \@hfiles;
}
############################################################################

############################################################################
# name: class:parent
sub updateMetaXml { #$t1, \%impts, $t2, $clsnames, $fns, $categ);
   my $node=$_[0];  my $name=$_[1];   my $clsnames=$_[2]; my $nodename=$_[3];
      
   my $fname="meta/${name}.xml";
   my $pkgname=getXmlAttr($node,"pkgname","");
   my $root= xmlRoot($fname, "cfile");
   my $flag=0;
   #print "pkg=${pkgname};\n";
   if ( $root->hasAttribute("name") && ($name eq $root->getAttribute("name"))) { $flag=0; }
   else { $root->setAttribute("name",$name); $flag=1; }
   if ( $root->hasAttribute("pkgname") && ($pkgname eq $root->getAttribute("pkgname"))) { 
      if ($pkgname) { $root->setAttribute("pkgname", $pkgname); $flag=1; }
   } 

   my ($t1,$t2);
   foreach $t1 (splitText($clsnames)) {
      $t1=trim($t1);  next unless ($t1);
      next if (hasNamedComponent($root, $t1)) ;#next if (hasNamedComponent($root,$nodename, $t1));
      $t2=$root->getOwner()->createElement($nodename);
      $t2->setAttribute("name", $t1); $root->addChild($t2);  $flag=1;
   }
   
   if ($flag) {  print "   *** update $fname\n"; xmlFile($root, $fname); }
   return $flag;
}
############################################################################

############################################################################
# ($t1, \%codes)
# message node: each item has the related set/getXXX method
#     size=0: hasXXX
#     size=n: sizeXXX(); nextXXX(); prevXXX();
#   <message name="" id="" internal="true|false" parents="">
#       <item name="" type="" size="0|1(d)|n">*
#   </message>
#
sub genMsgCode {


}