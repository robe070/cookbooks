// TestCrypto.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include <windows.h>
#include <stdio.h>
#include <Wincrypt.h>
#include <Cryptuiapi.h>

#define MY_ENCODING_TYPE  (PKCS_7_ASN_ENCODING | X509_ASN_ENCODING)

void MyHandleError(char *s);

typedef struct _ENUM_ARG {
   BOOL        fAll;
   BOOL        fVerbose;
   DWORD       dwFlags;
   const void  *pvStoreLocationPara;
   HKEY        hKeyBase;
} ENUM_ARG, *PENUM_ARG;

static BOOL WINAPI EnumPhyCallback(
   const void *pvSystemStore,
   DWORD dwFlags, 
   LPCWSTR pwszStoreName, 
   PCERT_PHYSICAL_STORE_INFO pStoreInfo,
   void *pvReserved, 
   void *pvArg);

static BOOL WINAPI EnumSysCallback(
   const void *pvSystemStore,
   DWORD dwFlags,
   PCERT_SYSTEM_STORE_INFO pStoreInfo,
   void *pvReserved,
   void *pvArg);

static BOOL WINAPI EnumLocCallback(
   LPCWSTR pwszStoreLocation,
   DWORD dwFlags,
   void *pvReserved,
   void *pvArg);

int _tmain(int argc, _TCHAR* argv[])
{

   //-------------------------------------------------------------------
   // Copyright (C) Microsoft.  All rights reserved.
   // This program lists all of the certificates in a system certificate
   // store and all of the property identifier numbers of those 
   // certificates. It also demonstrates the use of two
   // UI functions. One, CryptUIDlgSelectCertificateFromStore, 
   // displays the certificates in a store
   // and allows the user to select one of them, 
   // The other, CryptUIDlgViewContext,
   // displays the contents of a single certificate.

   //-------------------------------------------------------------------
   // Declare and initialize variables.

   HCERTSTORE       hCertStore;        
   PCCERT_CONTEXT   pCertContext=NULL;      
   WCHAR pwszNameString[256];
   WCHAR pwszStoreName[256];
   void*            pvData;
   DWORD            cbData;
   DWORD            dwPropId = 0; 
   // Zero must be used on the first
   // call to the function. After that,
   // the last returned property identifier is passed.

   //-------------------------------------------------------------------
   //  Begin processing and Get the name of the system certificate store 
   //  to be enumerated. Output here is to stderr so that the program  
   //  can be run from the command line and stdout can be redirected  
   //  to a file.

   fprintf(stderr,"Please enter the store name:");
   _getws_s( pwszStoreName, sizeof(pwszStoreName-1));
   fprintf(stderr,"The store name is %S.\n",pwszStoreName);

   //-------------------------------------------------------------------
   // Open a system certificate store.

   if ( hCertStore = CertOpenSystemStore(
      NULL,
      pwszStoreName))
   {
      fprintf(stderr,"The %S store has been opened. \n", 
         pwszStoreName);
   }
   else
   {
      // If the store was not opened, exit to an error routine.
      MyHandleError("The store was not opened.");
   }

   //-------------------------------------------------------------------
   // Use CertEnumCertificatesInStore to get the certificates 
   // from the open store. pCertContext must be reset to
   // NULL to retrieve the first certificate in the store.

   // pCertContext = NULL;

   while(pCertContext= CertEnumCertificatesInStore(
      hCertStore,
      pCertContext))
   {
      //-------------------------------------------------------------------
      // A certificate was retrieved. Continue.
      //-------------------------------------------------------------------
#if(0)
      //  Display the certificate.

      if ( CryptUIDlgViewContext(
         CERT_STORE_CERTIFICATE_CONTEXT,
         pCertContext,
         NULL,
         NULL,
         0,
         NULL))
      {
         //     printf("OK\n");
      }
      else
      {
         MyHandleError("UI failed.");
      }
#endif

      if(CertGetNameString(
         pCertContext,
         CERT_NAME_SIMPLE_DISPLAY_TYPE,
         0,
         NULL,
         pwszNameString,
         128))
      {
         printf("\nCertificate for %S \n",pwszNameString);
      }
      else
         fprintf(stderr,"CertGetName failed. \n");

      //-------------------------------------------------------------------
      // Loop to find all of the property identifiers for the specified  
      // certificate. The loop continues until 
      // CertEnumCertificateContextProperties returns zero.

      while(dwPropId = CertEnumCertificateContextProperties(
         pCertContext, // The context whose properties are to be listed.
         dwPropId))    // Number of the last property found.  
         // This must be zero to find the first 
         // property identifier.
      {
         //-------------------------------------------------------------------
         // When the loop is executed, a property identifier has been found.
         // Print the property number.

         printf("Property # %d found->", dwPropId);

         //-------------------------------------------------------------------
         // Indicate the kind of property found.

         switch(dwPropId)
         {
         case CERT_FRIENDLY_NAME_PROP_ID:
            {
               printf("Display name: ");
               break;
            }
         case CERT_SIGNATURE_HASH_PROP_ID:
            {
               printf("Signature hash identifier ");
               break;
            }
         case CERT_KEY_PROV_HANDLE_PROP_ID:
            {
               printf("KEY PROVE HANDLE");
               break;
            }
         case CERT_KEY_PROV_INFO_PROP_ID:
            {
               printf("KEY PROV INFO PROP ID ");
               break;
            }
         case CERT_SHA1_HASH_PROP_ID:
            {
               printf("SHA1 HASH identifier");
               break;
            }
         case CERT_MD5_HASH_PROP_ID:
            {
               printf("md5 hash identifier ");
               break;
            }
         case CERT_KEY_CONTEXT_PROP_ID:
            {
               printf("KEY CONTEXT PROP identifier");
               break;
            }
         case CERT_KEY_SPEC_PROP_ID:
            {
               printf("KEY SPEC PROP identifier");
               break;
            }
         case CERT_ENHKEY_USAGE_PROP_ID:
            {
               printf("ENHKEY USAGE PROP identifier");
               break;
            }
         case CERT_NEXT_UPDATE_LOCATION_PROP_ID:
            {
               printf("NEXT UPDATE LOCATION PROP identifier");
               break;
            }
         case CERT_PVK_FILE_PROP_ID:
            {
               printf("PVK FILE PROP identifier ");
               break;
            }
         case CERT_DESCRIPTION_PROP_ID:
            {
               printf("DESCRIPTION PROP identifier ");
               break;
            }
         case CERT_ACCESS_STATE_PROP_ID:
            {
               printf("ACCESS STATE PROP identifier ");
               break;
            }
         case CERT_SMART_CARD_DATA_PROP_ID:
            {
               printf("SMART_CARD DATA PROP identifier ");
               break;
            }
         case CERT_EFS_PROP_ID:
            {
               printf("EFS PROP identifier ");
               break;
            }
         case CERT_FORTEZZA_DATA_PROP_ID:
            {
               printf("FORTEZZA DATA PROP identifier ");
               break;
            }
         case CERT_ARCHIVED_PROP_ID:
            {
               printf("ARCHIVED PROP identifier ");
               break;
            }
         case CERT_KEY_IDENTIFIER_PROP_ID:
            {
               printf("KEY IDENTIFIER PROP identifier ");
               break;
            }
         case CERT_AUTO_ENROLL_PROP_ID:
            {
               printf("AUTO ENROLL identifier. ");
               break;
            }
         } // End switch.

         //-------------------------------------------------------------------
         // Retrieve information on the property by first getting the 
         // property size. 
         // For more information, see CertGetCertificateContextProperty.

         if(CertGetCertificateContextProperty(
            pCertContext, 
            dwPropId , 
            NULL, 
            &cbData))
         {
            //  Continue.
         }
         else
         {  
            // If the first call to the function failed,
            // exit to an error routine.
            MyHandleError("Call #1 to GetCertContextProperty failed.");
         }
         //-------------------------------------------------------------------
         // The call succeeded. Use the size to allocate memory 
         // for the property.

         if(pvData = (void*)malloc(cbData))
         {
            // Memory is allocated. Continue.
         }
         else
         {
            // If memory allocation failed, exit to an error routine.
            MyHandleError("Memory allocation failed.");
         }
         //----------------------------------------------------------------
         // Allocation succeeded. Retrieve the property data.

         if(CertGetCertificateContextProperty(
            pCertContext,
            dwPropId,
            pvData, 
            &cbData))
         {
            // The data has been retrieved. Continue.
         }
         else
         {
            // If an error occurred in the second call, 
            // exit to an error routine.
            MyHandleError("Call #2 failed.");
         }
         //---------------------------------------------------------------
         // Show the results.

         if ( cbData )
         {
            LPCWSTR pwszData = (LPCWSTR) pvData;
            CHAR *pchData = (CHAR *) pvData;
            if ( pwszData[cbData/2-1] == 0)
            {
               printf("The Property Content is %d bytes long. Wide String: '%S'", cbData, pvData);
            }
            else
            {
               printf("The Property Content is %d bytes long. Hex: ", cbData );
               for (int i = 0; i < cbData; i++ ) {
                  printf("%02X", (unsigned char) pchData[i] );
               }
            }
         }
         else
         {
            printf( "Flag");
         }
         putchar('\n');

         //----------------------------------------------------------------
         // Free the certificate context property memory.

         free(pvData);
      }  // End inner while.
   } // End outer while.

#if(0)
   //-------------------------------------------------------------------
   // Select a new certificate by using the user interface.

   if(!(pCertContext = CryptUIDlgSelectCertificateFromStore(
      hCertStore,
      NULL,
      NULL,
      NULL,
      CRYPTUI_SELECT_LOCATION_COLUMN,
      0,
      NULL)))
   {
      MyHandleError("Select UI failed." );
   }
#endif

   fprintf(stderr,"Press enter to end:");
   _getws_s( pwszStoreName, sizeof(pwszStoreName-1));

   //-------------------------------------------------------------------
   // Clean up.

   CertFreeCertificateContext(pCertContext);
   CertCloseStore(hCertStore,0);
   printf("The function completed successfully. \n");
} // End of main.


#if(0)
int OpenStore( void )
{
   HCERTSTORE hSysStore;
   hSysStore = CertOpenStore(
      CERT_STORE_PROV_SYSTEM,   // the store provider type
      0,                        // the encoding type is not needed
      NULL,                     // use the default HCRYPTPROV
      CERT_SYSTEM_STORE_CURRENT_USER, // set the store location in a registry location
      L"My"    // the store name as a Unicode string
      );

   // If call was successful, close hSystStore; otherwise, 
   // call print an error message.
   if(hSysStore)
   {
      if (!(CertCloseStore(hSysStore, 0)))
      {
         printf("Error closing system store.");
      }
   }
   else
      printf("Error opening system store.");

   exit( 0);
}
#endif

#if (0)
// The following code was originally the entire console application.
// Not currently called by any code
int EnumerateSystemStores( void )
{
   //-------------------------------------------------------------------
   // Declare and initialize variables.

   DWORD dwExpectedError = 0;
   DWORD dwLocationID = CERT_SYSTEM_STORE_CURRENT_USER_ID;
   DWORD dwFlags = 0;
   CERT_PHYSICAL_STORE_INFO PhyStoreInfo;
   ENUM_ARG EnumArg;
   LPSTR pszStoreParameters = NULL;          
   LPWSTR pwszStoreParameters = NULL;
   LPWSTR pwszSystemName = NULL;
   LPWSTR pwszPhysicalName = NULL;
   LPWSTR pwszStoreLocationPara = NULL;
   void *pvSystemName;                   
   void *pvStoreLocationPara;              
   DWORD dwNameCnt = 0;
   LPCSTR pszTestName;
   HKEY hKeyRelocate = HKEY_CURRENT_USER;
   LPSTR pszRelocate = NULL;               
   HKEY hKeyBase = NULL;

   //-------------------------------------------------------------------
   //  Initialize data structure variables.

   memset(&PhyStoreInfo, 0, sizeof(PhyStoreInfo));
   PhyStoreInfo.cbSize = sizeof(PhyStoreInfo);
   PhyStoreInfo.pszOpenStoreProvider = sz_CERT_STORE_PROV_SYSTEM_W;
   pszTestName = "Enum";  
   pvSystemName = pwszSystemName;
   pvStoreLocationPara = pwszStoreLocationPara;

   memset(&EnumArg, 0, sizeof(EnumArg));
   EnumArg.dwFlags = dwFlags;
   EnumArg.hKeyBase = hKeyBase;

   EnumArg.pvStoreLocationPara = pvStoreLocationPara;
   EnumArg.fAll = TRUE;
   dwFlags &= ~CERT_SYSTEM_STORE_LOCATION_MASK;
   dwFlags |= (dwLocationID << CERT_SYSTEM_STORE_LOCATION_SHIFT) &
      CERT_SYSTEM_STORE_LOCATION_MASK;

   printf("Begin enumeration of store locations. \n");
   if(CertEnumSystemStoreLocation(
      dwFlags,
      &EnumArg,
      EnumLocCallback
      ))
   {
      printf("\nFinished enumerating locations. \n");
   }
   else
   {
      MyHandleError("Enumeration of locations failed.");
   }
   printf("\nBegin enumeration of system stores. \n");

   if(CertEnumSystemStore(
      dwFlags,
      pvStoreLocationPara,
      &EnumArg,
      EnumSysCallback
      ))
   {
      printf("\nFinished enumerating system stores. \n");
   }
   else
   {
      MyHandleError("Enumeration of system stores failed.");
   }

   printf("\n\nEnumerate the physical stores "
      "for the MY system store. \n");
   if(CertEnumPhysicalStore(
      L"MY",
      dwFlags,
      &EnumArg,
      EnumPhyCallback
      ))
   {
      printf("Finished enumeration of the physical stores. \n");
   }
   else
   {
      MyHandleError("Enumeration of physical stores failed.");
   }

   exit (0);
}    //   End of main

//-------------------------------------------------------------------
//   Define function GetSystemName.

static BOOL GetSystemName( 
   const void *pvSystemStore,
   DWORD dwFlags, 
   PENUM_ARG pEnumArg, 
   LPCWSTR *ppwszSystemName )
{
   //-------------------------------------------------------------------
   // Declare local variables.

   *ppwszSystemName = NULL;

   if (pEnumArg->hKeyBase && 0 == (dwFlags & 
      CERT_SYSTEM_STORE_RELOCATE_FLAG)) 
   {
      printf("Failed => RELOCATE_FLAG not set in callback. \n");
      return FALSE;
   } 
   else 
   {
      if (dwFlags & CERT_SYSTEM_STORE_RELOCATE_FLAG) 
      {
         PCERT_SYSTEM_STORE_RELOCATE_PARA pRelocatePara;
         if (!pEnumArg->hKeyBase) 
         {
            MyHandleError("Failed => RELOCATE_FLAG is set in callback");
         }
         pRelocatePara = (PCERT_SYSTEM_STORE_RELOCATE_PARA) 
            pvSystemStore;
         if (pRelocatePara->hKeyBase != pEnumArg->hKeyBase) 
         {
            MyHandleError("Wrong hKeyBase passed to callback");
         }
         *ppwszSystemName = pRelocatePara->pwszSystemStore;
      } 
      else
      {
         *ppwszSystemName = (LPCWSTR) pvSystemStore;
      }
   }
   return TRUE;
}

//-------------------------------------------------------------------
// Define the callback functions.

static BOOL WINAPI EnumPhyCallback(
   const void *pvSystemStore,
   DWORD dwFlags, 
   LPCWSTR pwszStoreName, 
   PCERT_PHYSICAL_STORE_INFO pStoreInfo,
   void *pvReserved, 
   void *pvArg )
{
   //-------------------------------------------------------------------
   //  Declare and initialize local variables.
   PENUM_ARG pEnumArg = (PENUM_ARG) pvArg;
   LPCWSTR pwszSystemStore;

   //-------------------------------------------------------------------
   //  Begin callback process.

   if (GetSystemName(
      pvSystemStore, 
      dwFlags, 
      pEnumArg, 
      &pwszSystemStore))
   {
      printf("    %S", pwszStoreName);
   }
   else
   {
      MyHandleError("GetSystemName failed.");
   }
   if (pEnumArg->fVerbose &&
      (dwFlags & CERT_PHYSICAL_STORE_PREDEFINED_ENUM_FLAG))
      printf(" (implicitly created)");
   printf("\n"); 
   return TRUE;
}

static BOOL WINAPI EnumSysCallback(
   const void *pvSystemStore,
   DWORD dwFlags,
   PCERT_SYSTEM_STORE_INFO pStoreInfo,
   void *pvReserved,
   void *pvArg)
   //-------------------------------------------------------------------
   //  Begin callback process.
{
   //-------------------------------------------------------------------
   //  Declare and initialize local variables.

   PENUM_ARG pEnumArg = (PENUM_ARG) pvArg;
   LPCWSTR pwszSystemStore;
   static int line_counter=0;
   char x;

   //-------------------------------------------------------------------
   //  Begin processing.

   //-------------------------------------------------------------------
   //   Control break. If 5 or more lines have been printed,
   //   pause and reset the line counter.

   if(line_counter++ > 5)
   {
      printf("Enumeration of system store: Press Enter to continue.");
      scanf_s("%c",&x);
      line_counter=0;
   }

   //-------------------------------------------------------------------
   //  Prepare and display the next detail line.

   if (GetSystemName(pvSystemStore, dwFlags, pEnumArg, &pwszSystemStore))
   {
      printf("  %S\n", pwszSystemStore);
   }
   else
   {
      MyHandleError("GetSystemName failed.");
   }
   if (pEnumArg->fAll || pEnumArg->fVerbose) 
   {
      dwFlags &= CERT_SYSTEM_STORE_MASK;
      dwFlags |= pEnumArg->dwFlags & ~CERT_SYSTEM_STORE_MASK;
      if (!CertEnumPhysicalStore(
         pvSystemStore,
         dwFlags,
         pEnumArg,
         EnumPhyCallback
         )) 
      {
         DWORD dwErr = GetLastError();
         if (!(ERROR_FILE_NOT_FOUND == dwErr ||
            ERROR_NOT_SUPPORTED == dwErr))
         {
            printf("    CertEnumPhysicalStore");
         }
      }
   }
   return TRUE;
}

static BOOL WINAPI EnumLocCallback(
   LPCWSTR pwszStoreLocation,
   DWORD dwFlags,
   void *pvReserved,
   void *pvArg)

{
   //-------------------------------------------------------------------
   //  Declare and initialize local variables.

   PENUM_ARG pEnumArg = (PENUM_ARG) pvArg;
   DWORD dwLocationID = (dwFlags & CERT_SYSTEM_STORE_LOCATION_MASK) >>
      CERT_SYSTEM_STORE_LOCATION_SHIFT;
   static int linecount=0;
   char x;

   //-------------------------------------------------------------------
   //  Begin processing.

   //-------------------------------------------------------------------
   // Break if more than 5 lines have been printed.

   if(linecount++ > 5)
   {
      printf("Enumeration of store locations: "
         "Press Enter to continue.");
      scanf_s("%c",&x);
      linecount=0;
   }

   //-------------------------------------------------------------------
   //  Prepare and display the next detail line.

   printf("======   %S   ======\n", pwszStoreLocation);
   if (pEnumArg->fAll) 
   {
      dwFlags &= CERT_SYSTEM_STORE_MASK;
      dwFlags |= pEnumArg->dwFlags & ~CERT_SYSTEM_STORE_LOCATION_MASK;
      CertEnumSystemStore(
         dwFlags,
         (void *) pEnumArg->pvStoreLocationPara,
         pEnumArg,
         EnumSysCallback ); 
   }
   return TRUE;
}

#endif

void MyHandleError(char *s)
{
   fprintf(stderr,"An error occurred in running the program. \n");
   fprintf(stderr,"%s\n",s);
   fprintf(stderr, "Error number %x.\n", GetLastError());
   fprintf(stderr, "Program terminating. \n");
   exit(1);
} // End of MyHandleError