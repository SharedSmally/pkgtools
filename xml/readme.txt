product (product.xml)
   -> list-of-packages (package.xml)
   -> one-deployment-configuration (deploy.xml)
   
package (package.xml)
   -> list-of-libraries ()
        -> common library(library.xml)
              -> list-of-classes,structs,functions,...
        -> database library(database.xml)
              -> list-of-table (table.xml)
        -> protocol library (protocol.xml)
              -> list-of-message (message.xml)
        -> report library (report.xml)
              -> list-of-record (record.xml; from message)
        -> xml library (xml.xml)
              -> list-of-xsd (xsd.xml)
        -> json library (json.xml) 
        -> mibs (mib.xml)     

   -> list-of-applications (app.xml)

package-deployment-configuration (pdc/; deploy.xml)
   