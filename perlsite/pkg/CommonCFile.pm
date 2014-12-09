package CommonCFile;

use strict;
use warnings;
use Exporter;
#use Switch; switch() case;
use feature qw(switch);

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
our @EXPORT_OK = qw(  updateCFileMeta getInterfaces genCFileCode );

# these are exported by default.
our @EXPORT = qw( updateCFileMeta getInterfaces);

use Cwd;
my $mydir = getcwd;
####################################################
# common-used subroutines related to cfile node
####################################################
############################################################################
#  genCFileCode($mod,$cfilexml,$impts,$intfs)  
############################################################################
sub genCFileCode { # mod; xmlfile; impts; interfaces
   my $mod=$_[0];      my $xmlfile=$_[1];  
   my %impts=%{$_[2]}; my $interfaces=$_[3];

   print "${SP1}***parse cfile $xmlfile:\n";
   my $cnode=xmlRoot($xmlfile);
   my $cnodebak=$cnode->cloneNode(1);
   my $fname=$cnode->getAttribute("name");
   my $E0_NUM=3;
   #print "cnode:", $cnode->toString(1),"\n";
        
   my $clsns=getXmlAttr($mod,"namespace", "");
   $clsns=getXmlAttr($cnode,"namespace", $clsns);
   
   my $suf=getXmlAttr($cnode,"suffix","cc");
   $suf=".${suf}" unless ($suf =~ m/^\./);
    
   # parse existing code from *.cc and *.h files 
   my @labelFiles=("${fname}.h", "${fname}${suf}");
   my %codes = %{parseLabelFiles( (\@labelFiles) )}; 

   my (@ha, @iha, @ca, $t1, $t2, $flag); $flag=0;
   
   # pre*code/post*code
   my $extC= xml_true($cnode,"extC"); 
   my $ext= ( xml_true($cnode,"ext") || xml_true($cnode, "extension") );
   
   if  ($ext) {  ###########  extra signature for cfile/class.
      push(@ha,getLabelStr("pre_${fname}.h", \%codes));
      push(@ca,getLabelStr("pre_${fname}${suf}", \%codes));
   }      

   foreach $t1 ($cnode->childNodes) {
      next if ($t1->nodeType != XML_ELEMENT_NODE); 
           
      if ($t1->nodeName eq "decl")    { 
      	push(@ha, @{genDeclCode($t1)}); 
      	$flag=1; next;
      }
      
      if ($t1->nodeName eq "using")   { 
      	push(@ha, @{genUsingCode($t1)}); 
      	$flag=1; next;
      }
      if ($t1->nodeName eq "define")  { 
      	push(@ha, genDefineCode($t1));  
      	$flag=1; next;      	
      }
      
      if ($t1->nodeName eq "typedef") {
      	push(@ha, genTypeDefCode($t1)); 
      	$flag=1; next;
      }
      
      if ($t1->nodeName eq "deffn")   { 
      	 push(@ha, genFuncDefCode($t1)); 
      	 $flag=1; next;      	
      }
      if ($t1->nodeName eq "funcdef") { 
      	push(@ha, genFuncDefCode($t1)); 
      	$flag=1; next;
      }
      
      if ($t1->nodeName eq "enum")    { 
      	push(@ha, genEnumCode($t1)); 
      	$flag=1; next;
      }
      if ($t1->nodeName eq "union")   { 
      	push(@ha, genUnionCode($t1)); 
      	$flag=1; next;
      } 
      
      if ($t1->nodeName eq "var")     { 
      	my ($x1,$x2)=genVarCode($t1);   
      	push(@ha,$x1);   push(@ca,$x2) if ($x2); 
      	$flag=1; next;
      } 
      
      if ($t1->nodeName eq "const")   {
      	 my ($x1,$x2)=genConstCode($t1); 
      	 push(@ha,$x1); 
      	 push(@ca,$x2) if ($x2); 
      	 $flag=1; next;
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
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes, $interfaces);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { 
         	push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; 
         } 
         push(@ca, @{$cavar}) if (@{$cavar});   
         push(@iha, @{$ihavar}) if (@{$ihavar});
         next;  
      }
      
      if ($t1->nodeName eq "struct") {
         $t1->setAttribute("struct","true"); 
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes, $interfaces);
         if ($havar && (scalar(@{$havar})>$E0_NUM)) { 
         	push(@ha, "") if ($flag);    push(@ha, @{$havar});  $flag=0; 
         } 
         push(@ca, @{$cavar}) if (@{$cavar});   
         push(@iha, @{$ihavar}) if (@{$ihavar});  
         next;
      } 
      
      if ($t1->nodeName eq "interface") { 
         my ($havar, $cavar, $ihavar) = genClassCode($t1, \%codes, $interfaces);
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
         if (xml_true($t1,"c") || xml_true($t1,"c")) { push(@ca, $txt); }
         else { push(@ha, $txt); }
      }        
   }
   
   #print "\ncnode2:", $cnode->toString(1);
   # module: pkgname::mod-name
   # library:pkgname::libname 
         
   my $imptname=getXmlAttr($mod,"name","");
   if ($mod->hasAttribute("module")) {
       $imptname = getXmlAttr($mod,"module",""); 
       $imptname .="_" if ($imptname); 
       $imptname .= getXmlAttr($mod,"name","");
   } else {
   	   $imptname = getXmlAttr($mod,"libname");
   }
   #unless (exists $impts{$imptname} ) {
   #  $imptname = $mod->getAttribute("pkgname")."::${imptname}";
   #}
   my $himpt = getHFileImportStr( $cnode, $_[2], $imptname);
   my $cimpt = getCFileImportStr( $cnode, $_[2], $imptname); 
   $cimpt .="\n" if ($cimpt);
   
   if (exists $impts{$imptname} ) {
        $cimpt .= getCImportStr($fname,$impts{$imptname}); 
        $cimpt .="\n";
   }

   # post*code
   if ($ext) {
      push(@ha, getLabelStr("post_${fname}.h", \%codes));
      push(@ca, getLabelStr("post_${fname}${suf}", \%codes));
   }

   my $nca = @ca; my $nha = @ha;
   if ( $extC ) {
   	    unshift(@ha, "extern \"C\" { ");     push(@ha, "} ");
   		if ($nca) { unshift(@ca, "extern \"C\" { ") ; push(@ca, "} ");} 
   }
   
   if ($nha) {   
   	  saveHCode($fname, $clsns, $himpt, \@ha, $BACKUP, \@iha) ;
	
	  # link *.h header file.
   	  my $hdir=getIncludeHome($mod); 
      system("mkdir -p $hdir") unless (-d $hdir) ;
      
      info(" link ${fname}.h to ${hdir}${fname}.h");
      system("rm -rf ${hdir}${fname}.h; ln -s $mydir/${fname}.h ${hdir}${fname}.h");    	  
   }
   
   saveCCCode($fname, $clsns, $cimpt, \@ca, $BACKUP) if ($nca);
         
   # testing cases for cfile node
   #print "cnode:", $cnodebak->toString(1),"\n";
   my $utests = genUnitTest($cnodebak);
   
   return ($nca, $utests);
}

############################################################################

############################################################################
# update meta/*.xml based on library.xml/module.xml:
# <module name="" category="" namespace="" subdir="">
#    <cfile> list of classes </cfile>*  each has its own *.cc and *.h
#    <cfile file=""> list of classes </cfile>: share the same *.cc and *.h
# </module> 
############################################################################
my @flag_nodes=("import","impt_interface","flag","flags","inc","incpath","libpath","library","lib");
my @cls_nodes=("class","interface");
sub updateCFileMeta {
   my $node=$_[0]; 
   
   system("mkdir -p ./meta") unless (-d "./meta");
   my $modname="";
   $modname=getXmlAttr($node,"name","") if ($node->nodeName eq "module");
    
   my ($t1,$t2, @hfiles); 
   #foreach $t1 ($node->getChildrenByTagName("cfile")) {
   foreach $t1 ($node->childNodes) {
     next if ($t1->nodeType != XML_ELEMENT_NODE);
     next if (contains($t1->nodeName,\@flag_nodes));
     my $ns=getXmlAttr($t1,"namespace","");
     if ($t1->hasAttribute("file")) { 
          $t2=trim($t1->getAttribute("file")); push(@hfiles,$t2);
          updateMetaXml($node, $t2, $t1->textContent, $t1->nodeName,$ns,$modname);
     } else { 
        foreach $t2 (splitXmlText($t1)) {
           $t2=trim($t2); next unless ($t2);  push(@hfiles, $t2);
           updateMetaXml($node, $t2, $t2, $t1->nodeName,$ns,$modname); 
        }
     }
   } 
   
   #links to import_std.xml
   my $t0=getPkgHome($node);
   $t1="${t0}/pkg/repos_pkg.xml"; $t2="meta/import_pkg.xml";
   if (-f $t1) {  info("link $t1 to $t2"); system("rm -rf ${t2}; ln -s ${t1} ${t2}"); } 

   $t1="${t0}/pkg/import_std.xml"; $t2="meta/import_std.xml";
   if (-f $t1) {  info("link $t1 to $t2"); system("rm -rf ${t2}; ln -s ${t1} ${t2}"); } 

   return \@hfiles;
}
############################################################################

############################################################################
# <cfile>
#    <class><interface>...</interface>/class>*
#    <interface>...</interface>*
# </cfile>
############################################################################
sub getInterfaces {
    my @cfiles=@{$_[0]};  my $rootnode=$_[1];
    
    my %intfs;  my ($t1,$t2,$t3,$node,$n0,$name);
    
    ##  get list-of-interfaces
    foreach $t1 (@cfiles) {
       $node=xmlRoot("./meta/${t1}.xml");
       foreach $n0 ($node->childNodes) {
          next if ($n0->nodeType != XML_ELEMENT_NODE);
          $name=$n0->getAttribute("name");
          if ($n0->nodeName eq "interface") { # the class is an interface
            if (exists $intfs{$name} ) {   print "***  interface ${name} already exists.\n"; }
            else { $intfs{$name}=[$node];    print "      **add class interface for $name\n"; }
          } else {
            foreach $t2 ($n0->getChildrenByTagName("interface")) { #interface group
               if (exists $intfs{$name} ) { push(@{$intfs{$name}}, $t2); }
               else {$intfs{$name}=[$t2]; }
               print "      **add member interface for $name\n";
            }
          }
       }
    }

    foreach $t1 ($rootnode->getChildrenByTagName("impt_interface")) {
      $t2=getXmlAttr($t1,"prefix","");$t3=getXmlAttr($t1,"suffix",".xml");
       
      foreach my $t4 (splitXmlText($t1)) {
        $node=xmlRoot("${t2}${t4}${t3}");

        foreach $n0 ($node->childNodes) {
          next if ($n0->nodeType != XML_ELEMENT_NODE);
          $name=$n0->getAttribute("name");
          if ($n0->nodeName eq "interface") { # the class is an interface
            if (exists $intfs{$name} ) {   print "***  interface ${name} already exists.\n"; }
            else { $intfs{$name}=[$node];    print "      **add class interface for $name\n"; }
          } else {
            foreach $t2 ($n0->getChildrenByTagName("interface")) { #interface group
               if (exists $intfs{$name} ) { push(@{$intfs{$name}}, $t2); }
               else {$intfs{$name}=[$t2]; }
               print "      **add member interface for $name\n";
            }
          }
        }
      }
    }    
    return \%intfs;
}

############################################################################

############################################################################
# name: class:parent
sub updateMetaXml { #$t1, \%impts, $t2, $clsnames, $fns, $categ);
   my ($node,$name,$clsnames,$nodename,$namespace,$modname)=@_;
      
   my $fname="meta/${name}.xml";
   my $pkgname=getXmlAttr($node,"pkgname","");
   my $libname=getXmlAttr($node,"libname","");   
   my $root= xmlRoot($fname, "cfile");
   my $flag=0;
   #print "node:", $node->toString(1),"\n";
   
   if ( $root->hasAttribute("name") && ($name eq $root->getAttribute("name"))) { $flag=0; }
   else { $root->setAttribute("name",$name); $flag=1; }
   
   unless ( $root->hasAttribute("pkgname") && ($pkgname eq $root->getAttribute("pkgname"))) { 
      if ($pkgname) { $root->setAttribute("pkgname", $pkgname); $flag=1; }
   } 
   unless ( $root->hasAttribute("libname") && ($libname eq $root->getAttribute("libname"))) { 
      if ($pkgname) { $root->setAttribute("libname", $libname); $flag=1; }
   } 
   unless ( $root->hasAttribute("namespace") && ($namespace eq $root->getAttribute("namespace"))) { 
      if ($namespace) { $root->setAttribute("namespace", $namespace); $flag=1; }
   } 
   
   if ($modname) { $root->setAttribute("modname", $modname); $flag=1; }
      
   my ($t1,$t2);
   foreach $t1 (splitText($clsnames)) {
      $t1=trim($t1);  next unless ($t1);
      next if (hasNamedComponent($root, $t1)) ;#next if (hasNamedComponent($root,$nodename, $t1));
      $t2=$root->getOwner()->createElement($nodename);
      $t2->setAttribute("name", $t1); $root->addChild($t2);  $flag=1;
      
      my $pub=$root->getOwner()->createElement("public");
      $t2->addChild($pub);
      my $c1=$root->getOwner()->createElement("constructor");
      my $a1=$root->getOwner()->createElement("arg");
      $a1->setAttribute("name","a1");$a1->setAttribute("type","std::string");
      $c1->addChild($a1); $pub->addChild($c1);
      my $c2=$root->getOwner()->createElement("deconstructor");
      $c2->setAttribute("virtual","true");  
      $c2->addChild($root->getOwner()->createTextNode("\n      ")); 
      $pub->addChild($c2);

	  #$t2->addChild($root->getOwner()->createTextNode("\n"));             
      my $prot=$root->getOwner()->createElement("protected");
      $t2->addChild($prot);
      my $v1=$root->getOwner()->createElement("var");
      $v1->setAttribute("name","v1");$v1->setAttribute("type","std::string");
      $prot->addChild($v1);      
   }
   
   if ($flag) {  print "   *** update $fname\n"; xmlFile($root, $fname); }
   return $flag;
}

