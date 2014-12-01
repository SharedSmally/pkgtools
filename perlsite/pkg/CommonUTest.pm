package CommonUTest;

use strict;
use warnings;
use Exporter;

###############################################################
#define a module for unit test
our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( genUnitTest);

# these are exported by default.
our @EXPORT = qw( genUnitTest );

###############################################################
use Common  qw(trim splitText writeArray);
use CommonMD5 qw(parseLabelFile getMDLabels);
use CommonXml  qw(getXmlAttr);
############################################################################
#  generate unit test code
###############################################################
# generate unit test from <test>list-of-test-function</test> node

#include "../XXX.h"
#using namespace cpw::thread;
#
#include <stdlib.h>
#include <iostream>

#include <cppunit/TestFixture.h>
#include <cppunit/Asserter.h>
#include <cppunit/TestAssert.h>
#include <cppunit/TestCaller.h>
#include <cppunit/ui/text/TestRunner.h>
#include <iostream>

#class XXXTestFixture : public CppUnit::TestFixture
#{
#private:
#
#protected:
#
#public:
#
#public:
#  void setUp(){
#   .......
#  }
#
#  void tearDown(){
#   ........
#  }
#
#  void testXXX()
#  {
#
#  }
#
#
#public:
#  static CppUnit::Test * suite()
#  {
#    CppUnit::TestSuite *suiteOfTests = new CppUnit::TestSuite( "XXXTest" );
#    suiteOfTests->addTest( new CppUnit::TestCaller<XXXTestFixture >(
#                      "testYYY", &XXXTestFixture::testYYY) );
#    return suiteOfTests;
#  }
#  
#  Alterative method:
#  #The suite created by the static suite() method is named after the class name.
#  CPPUNIT_TEST_SUITE( XXXTest );
#  #Then, we declare each test case of the fixture: 
#  CPPUNIT_TEST( testEquality );
#  CPPUNIT_TEST( testAddition );
#  #Finally, we end the suite declaration:
#  CPPUNIT_TEST_SUITE_END(); 
#
#};
#
#int main( int argc, char **argv)
#{
#  CppUnit::TextUi::TestRunner runner;
#  runner.addTest( XXXTestFixture::suite() );
#  runner.run();
#  return 0;
#}
# generate unit test from cfile node; which has multiple <class> node
#    while <class> has multiple <test> node
#
# compile unitTests: 
#   g++ -o testThread testThread.cc -lcppunit -I../../../../include
#
sub genUnitTest {
   my $node = $_[0];  # cnode
   
   my $name = $node->getAttribute("name");
   my $clsns=getXmlAttr($node,"namespace",""); 
   $clsns =~ s/\./::/g;
   my $uname =  ucfirst($name);
   my $file="test/test${uname}.cc";
   my %codes;
   
   if (-f $file) { 
      my $s = parseLabelFile($file);  
      while ( my ($key, $val) = each %{$s} ) {  $codes{$key}=$val; }
   }
   
   my ($x0,@ca);
   my ($ss, $mds1, $mds2, $mds3);
   
   push(@ca,"// User Pre-Defined Codes for $file");
   $ss="${file}Prefix";
   ($mds1, $mds2, $mds3)=getMDLabels($ss);
   $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
   push(@ca, "${mds1}${ss}${mds2}");
   push(@ca,"");
   
   push(@ca,"#include \"../${name}.h\"");
   push(@ca,"using namespace $clsns;") if ($clsns);
   push(@ca,"");
   push(@ca,"#include <stdlib.h>");
   push(@ca,"#include <iostream>");
   push(@ca,"using namespace std;");
   push(@ca,"");
   push(@ca,"#include <cppunit/TestFixture.h>");
   push(@ca,"#include <cppunit/Asserter.h>");
   push(@ca,"#include <cppunit/TestAssert.h>");
   push(@ca,"#include <cppunit/TestCaller.h>");
   push(@ca,"#include <cppunit/ui/text/TestRunner.h>");
   push(@ca,"");

   my (@classes,$t0,$t1,$t2,$clsname);
   
      
   push(@ca,"// User Defined Codes for $file");
   $ss=$file;
   ($mds1, $mds2, $mds3)=getMDLabels($ss);
   $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
   push(@ca, "${mds1}${ss}${mds2}");
   push(@ca,"");
      
   push(@ca,"//CPPUNIT_ASSERT(); //condition)"); 
   push(@ca,"//CPPUNIT_ASSERT_MESSAGE(,); //(message, condition)"); 
   push(@ca,"//CPPUNIT_FAIL(); //(message)"); 
   push(@ca,"//CPPUNIT_ASSERT_EQUAL(,); //(expected, actual)"); 
   push(@ca,"//CPPUNIT_ASSERT_EQUAL_MESSAGE(,,); //(message, expected, actual)"); 
   push(@ca,"//CPPUNIT_ASSERT_DOUBLES_EQUAL(,,); //(expected, actual, delta)"); 
   push(@ca,"//CPPUNIT_ASSERT_THROW(,); //(expression, ExceptionType)"); 
   push(@ca,"//CPPUNIT_ASSERT_NO_THROW(); //(expression)"); 
   push(@ca,"//CPPUNIT_ASSERT_ASSERTION_FAIL(); //(assertion)"); 
   push(@ca,"//CPPUNIT_ASSERT_ASSERTION_PASS(); //(assertion)"); 
   push(@ca,"");
   
   #foreach $t1 ($node->getChildrenByTagName("class") ) {#class or interface
   foreach $t1 ($node->childNodes) {
      next if ( ($t1->nodeName ne "class") && 
                ($t1->nodeName ne "struct") && ($t1->nodeName ne "interface"));
      $t0=""; $clsname=$t1->getAttribute("name");
      foreach $t2 ($t1->getChildrenByTagName("test") ) {
         $t0 .= ","; $t0 .= $t2->textContent;
      }
      next unless ($t0);
      push(@classes,$clsname);
      push(@ca,"class ${clsname}TestFixture : public CppUnit::TestFixture");
      push(@ca,"{");
      push(@ca,"private:");
      $ss="${clsname}::private";
      ($mds1, $mds2, $mds3)=getMDLabels($ss);
      $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
      push(@ca, "${mds1}${ss}${mds2}");
      push(@ca,"");
      
      push(@ca,"protected:");
      $ss="${clsname}::protected";
      ($mds1, $mds2, $mds3)=getMDLabels($ss);
      $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
      push(@ca, "${mds1}${ss}${mds2}");
      push(@ca,"");
      
      push(@ca,"public:");
      $ss="${clsname}::public";
      ($mds1, $mds2, $mds3)=getMDLabels($ss);
      $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
      push(@ca, "${mds1}${ss}${mds2}");
      push(@ca,"");
            
      push(@ca,"public:");
      push(@ca,"   void setUp()");
      push(@ca,"   {");
      $ss="${clsname}::setup()";
      ($mds1, $mds2, $mds3)=getMDLabels($ss);
      $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
      push(@ca, "${mds1}${ss}${mds2}");
      push(@ca,"   }");
      push(@ca,"");
      
      push(@ca,"   void tearDown()");
      push(@ca,"   {");
      $ss="${clsname}::tearDown()";
      ($mds1, $mds2, $mds3)=getMDLabels($ss);
      $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
      push(@ca, "${mds1}${ss}${mds2}");
      push(@ca,"   }");
      push(@ca,"");

      foreach $t1 ( splitText($t0)) {
        $t1=trim($t1); next unless ($t1);
        push(@ca,"   void test${t1}()");
        push(@ca,"   {");
        $ss="${clsname}::tear${t1}()";
        ($mds1, $mds2, $mds3)=getMDLabels($ss);
        $ss="\n"; $ss.=$codes{$mds3} if (exists $codes{$mds3} ); 
        push(@ca, "${mds1}${ss}${mds2}");
        push(@ca,"   }");
        push(@ca,"");
      }
      
      push(@ca,"public:");
      push(@ca,"   static CppUnit::Test *suite()");
      push(@ca,"   {");
      push(@ca,"      CppUnit::TestSuite *suiteOfTests = new CppUnit::TestSuite( \"${clsname}Test\" );");
      foreach $t1 ( splitText($t0)) {
         $t1=trim($t1); next unless ($t1);
         push(@ca,"      suiteOfTests->addTest( new CppUnit::TestCaller<${clsname}TestFixture >(");
         push(@ca,"          \"test ${clsname}::${t1}\", &${clsname}TestFixture::test${t1}) );");
      }
      push(@ca,"      return suiteOfTests;");
      push(@ca,"   }");
      push(@ca,"");
      push(@ca,"};");
      push(@ca,"");
   }
   
   return "" if (scalar(@classes)==0);
   
   # main:
   push(@ca,"//int main( int argc, char **argv)");
   push(@ca,"int main( int , char **)");
   push(@ca,"{");
   push(@ca,"   CppUnit::TextUi::TestRunner runner;");
   foreach $x0 (@classes) {
     push(@ca,"   runner.addTest( ${x0}TestFixture::suite() );");
   }
   push(@ca,"   runner.run();");
   push(@ca,"   return 0;");
   push(@ca,"}\n");
   
   writeArray($file, \@ca);
   
   return $file;
}
1
###############################################################