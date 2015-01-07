// TestCrypto.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"

#include <windows.h>
#include <stdio.h>
#include <Wincrypt.h>
#include <Cryptuiapi.h>
#include <ncrypt.h>
#include <stdint.h>

#define MY_ENCODING_TYPE  (PKCS_7_ASN_ENCODING | X509_ASN_ENCODING)

void MyHandleError(char *s);
uint8_t hextobin(const char * str, uint8_t * bytes, size_t blen);
void findPrivateKey();
void EnumAllCerts();
BOOL fCheckCertAttribute( DWORD dwPropId, BYTE *pvMatchData, SHORT sMatchLen, DWORD dwOffset );

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

HCERTSTORE       hCertStore;        
PCCERT_CONTEXT   pCertContext;      
WCHAR pwszNameString[256];
WCHAR pwszStoreName[256];
void*            pvData;
DWORD            cbData;
DWORD            dwPropId; 

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

   // Zero must be used on the first
   // call to the function. After that,
   // the last returned property identifier is passed.

   //-------------------------------------------------------------------
   //  Begin processing and Get the name of the system certificate store 
   //  to be enumerated. Output here is to stderr so that the program  
   //  can be run from the command line and stdout can be redirected  
   //  to a file.
   pCertContext=NULL;

   fprintf(stderr,"Please enter the store name:");
   _getws_s( pwszStoreName, sizeof(pwszStoreName));
   fprintf(stderr,"The store name is %S.\n",pwszStoreName);

   //-------------------------------------------------------------------

#if(0)
   // Open a system certificate store in CURRENT_USER.
   if ( hCertStore = CertOpenSystemStore(
      NULL,
      pwszStoreName))
#endif
   // Open a system certificate store in LOCAL_MACHINE.
   if(hCertStore = CertOpenStore(
      CERT_STORE_PROV_SYSTEM,          // The store provider type
      0,                               // The encoding type is not needed
      NULL,                            // Use the default HCRYPTPROV
      CERT_SYSTEM_STORE_LOCAL_MACHINE, // Set the store location in a registry location
      pwszStoreName                    // The store name as a Unicode string
      ))
   {
      fprintf(stderr,"The %S store has been opened. \n", 
         pwszStoreName);
   }
   else
   {
      // If the store was not opened, exit to an error routine.
      MyHandleError("The store was not opened.");
   }

   if ( argc > 1 )
   {
      if ( argv[1][0] == L'p') findPrivateKey( );
      else  MyHandleError("Invalid option");
   }
   else
   {
      EnumAllCerts();
   }


   fprintf(stderr,"Press enter to end: \n");
   _getws_s( pwszStoreName, sizeof(pwszStoreName-1));

   //-------------------------------------------------------------------
   // Clean up.

   CertFreeCertificateContext(pCertContext);
   CertCloseStore(hCertStore,0);
   printf("The function completed successfully. \n");

   exit(0);


} // End of main.

void EnumAllCerts()
{
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

      dwPropId = 0;
      while(dwPropId = CertEnumCertificateContextProperties(
         pCertContext, // The context whose properties are to be listed.
         dwPropId))    // Number of the last property found.  
         // This must be zero to find the first 
         // property identifier.
      {
         //-------------------------------------------------------------------
         // When the loop is executed, a property identifier has been found.
         // Print the property number.

         printf("Property # %*d ", 2, dwPropId);

         //-------------------------------------------------------------------
         // Indicate the kind of property found.
         DWORD dwOffset = 0;
         switch(dwPropId)
         {
         case CERT_FRIENDLY_NAME_PROP_ID:
            {
               printf("%-*s", 29, "Display name. ");
               break;
            }
         case CERT_SIGNATURE_HASH_PROP_ID:
            {
               printf("%-*s", 29, "Signature hash. ");
               break;
            }
         case CERT_KEY_PROV_HANDLE_PROP_ID:
            {
               printf("%-*s", 29, "KEY PROVIDER HANDLE. ");
               break;
            }
         case CERT_KEY_PROV_INFO_PROP_ID:
            {
               printf("%-*s", 29, "KEY PROVIDER INFO. ");
               // The printable text is at an offset into the property
               dwOffset = 14;
               break;
            }
         case CERT_SHA1_HASH_PROP_ID:
            {
               printf("%-*s", 29, "SHA1 HASH. ");
               break;
            }
         case CERT_MD5_HASH_PROP_ID:
            {
               printf("%-*s", 29, "MD5 hash. ");
               break;
            }
         case CERT_SUBJECT_PUBLIC_KEY_MD5_HASH_PROP_ID:
            {
               printf("%-*s", 29, "SUBJECT PUBLIC KEY MD5 HASH. ");
               break;
            }
         case CERT_KEY_CONTEXT_PROP_ID:
            {
               printf("%-*s", 29, "KEY CONTEXT. ");
               break;
            }
         case CERT_KEY_SPEC_PROP_ID:
            {
               printf("%-*s", 29, "KEY SPEC. ");
               break;
            }
         case CERT_ENHKEY_USAGE_PROP_ID:
            {
               printf("%-*s", 29, "ENHKEY USAGE. ");
               break;
            }
         case CERT_NEXT_UPDATE_LOCATION_PROP_ID:
            {
               printf("%-*s", 29, "NEXT UPDATE LOCATION. ");
               break;
            }
         case CERT_PVK_FILE_PROP_ID:
            {
               printf("%-*s", 29, "PVK FILE. ");
               break;
            }
         case CERT_DESCRIPTION_PROP_ID:
            {
               printf("%-*s", 29, "DESCRIPTION. ");
               break;
            }
         case CERT_ACCESS_STATE_PROP_ID:
            {
               printf("%-*s", 29, "ACCESS STATE. ");
               break;
            }
         case CERT_SMART_CARD_DATA_PROP_ID:
            {
               printf("%-*s", 29, "SMART_CARD DATA. ");
               break;
            }
         case CERT_EFS_PROP_ID:
            {
               printf("%-*s", 29, "EFS. ");
               break;
            }
         case CERT_FORTEZZA_DATA_PROP_ID:
            {
               printf("%-*s", 29, "FORTEZZA DATA. ");
               break;
            }
         case CERT_ARCHIVED_PROP_ID:
            {
               printf("%-*s", 29, "ARCHIVED. ");
               break;
            }
         case CERT_KEY_IDENTIFIER_PROP_ID:
            {
               printf("%-*s", 29, "KEY IDENTIFIER. ");
               break;
            }
         case CERT_AUTO_ENROLL_PROP_ID:
            {
               printf("%-*s", 29, "AUTO ENROL. ");
               break;
            }
         case CERT_SIGN_HASH_CNG_ALG_PROP_ID:
            {
               printf("%-*s", 29, "SIGN HASH CNG ALG. ");
               break;
            }
         case CERT_SUBJECT_PUB_KEY_BIT_LENGTH_PROP_ID:
            {
               printf("%-*s", 29, "SUBJECT PUB KEY BIT LENGTH. ");
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

            if ( dwOffset )
            {
               pwszData = pwszData + dwOffset;

               printf("Content is %*d bytes long. Wide String at offset %d: '%S'", 3, cbData, dwOffset, pwszData);
            }
            else if ( cbData > 4 && pwszData[cbData/2-1] == 0) // If its 4 bytes or less its presumed to be numeric. e.g. a 64 bit integer
            {
               printf("Content is %*d bytes long. Wide String: '%S'", 3, cbData, pwszData);
            }
            else
            {
               printf("Content is %*d bytes long. Hex: ", 3, cbData );
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
}

// Finds a certificate matching a SHA1 Hash, and then checks if it has a matching GUID and Key Identifier Prop and is a private key or not
#define SHA1_LEN  20
#define GUID_LEN  36
#define KEY_ID_LEN 20

void findPrivateKey( )
{
   //-------------------------------------------------------------------
   // Get a particular certificate using CertFindCertificateInStore.
   CHAR Sha1HashData[101];
   WCHAR GUID[101];
   CHAR KeyID[101];
   BOOL fEntered = FALSE;

   while ( !fEntered )
   {
      fprintf(stderr,"Please enter the SHA1 Hash to find:");
      gets_s( Sha1HashData, 101);

      if ( strlen( Sha1HashData ) > 40)
      {
         fprintf( stderr, "Hash is too long\n");
      }
      else
      {
         fEntered = TRUE;
      }
   }

   fprintf(stderr,"Please enter the GUID to match:");
   _getws_s( GUID, 50);

   fprintf(stderr,"Please enter the Key Identifier to match:");
   gets_s( KeyID, 101);


   // CHAR  * Sha1HashData = "244D8DFFE7DB4263B45102A277C9C362B009D8AF"; // Private key exists in MY store
   // D559A586669B08F46A30A133F8A9ED3D038E2EA8 // Private key DOES NOT EXIST in CA
   
   BYTE  ByteData[SHA1_LEN];
   CRYPT_INTEGER_BLOB Sha1Hash;
   Sha1Hash.cbData = sizeof( ByteData);
   Sha1Hash.pbData = ByteData;
   hextobin( Sha1HashData, ByteData, sizeof( ByteData) );

   BYTE  KeyIDData[KEY_ID_LEN];
   hextobin( KeyID, KeyIDData, sizeof( KeyIDData) );

   if(pCertContext = CertFindCertificateInStore(
      hCertStore,             // Store handle.
      MY_ENCODING_TYPE,       // Encoding type.
      0,                      // Not used.
      CERT_FIND_SHA1_HASH,    // Find type. Find SHA1 Hash in Certificate. Presumed unique
      &Sha1Hash,              // The SHA1 Hash to be searched for.
      pCertContext ))         // Previous context.
   {
      printf("Found the certificate. \n");
   }
   else
   {
      MyHandleError("Could not find the required certificate");
   }

   // Check the GUID matches
   if ( !fCheckCertAttribute(  CERT_KEY_PROV_INFO_PROP_ID, (BYTE *)GUID, 36, 28 ) )
   {
      MyHandleError("GUID does not match");
   }

   // Check the Key Identifier matches
   if ( !fCheckCertAttribute(  CERT_KEY_IDENTIFIER_PROP_ID, (BYTE *)KeyIDData, 20, 0 ) )
   {
      MyHandleError("Key Identifier does not match");
   }

   printf("Certificate matches GUID and Key Identifier attributes. \n");

   // Check the certificate has a Private Key

   HCRYPTPROV hCryptProv;
   DWORD dwKeySpec;
   BOOL  fCallerFree = FALSE;

   if(!( CryptAcquireCertificatePrivateKey(
      pCertContext,
      0,
      NULL,
      &hCryptProv,
      &dwKeySpec,
      &fCallerFree )))
   {
      printf( "A private key does not exist\n");
   }
   else
   {
      printf( "A private key exists\n");

      if (fCallerFree)
      {
         if ( dwKeySpec == CERT_NCRYPT_KEY_SPEC)
         {
            NCryptFreeObject( hCryptProv );
         }
         else
         {
            CryptReleaseContext( hCryptProv, 0 );
         }
      }
   }
}

// Check Attribute
BOOL fCheckCertAttribute( DWORD dwPropId, BYTE *pvMatchData, SHORT sMatchLen, DWORD dwOffset )
{
   BYTE *pCertData = NULL;

   if (CertGetCertificateContextProperty(
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
      MyHandleError("Call #1 to CertGetCertificateContextProperty failed.");
   }
   //-------------------------------------------------------------------
   // The call succeeded. Use the size to allocate memory 
   // for the property.

   if(pCertData = (BYTE*)malloc(cbData))
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
      pCertData, 
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

   if ( cbData )
   {
      return (memcmp(pvMatchData, pCertData + dwOffset, sMatchLen) == 0);
   }
   else
   {
      return FALSE;
   }

   // ** Need to free pCertData
}

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


uint8_t hextobin(const char * str, uint8_t * bytes, size_t blen)
{
   uint8_t  pos;
   uint8_t  idx0;
   uint8_t  idx1;

   // mapping of ASCII characters to hex values
   const uint8_t hashmap[] =
   {
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //  !"#$%&'
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ()*+,-./
      0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
      0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
      0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // HIJKLMNO
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // PQRSTUVW
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // XYZ[\]^_
      0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // `abcdefg
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // hijklmno
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // pqrstuvw
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // xyz{|}~.
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ........
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // ........
   };

   memset(bytes, '\0', blen);
   for (pos = 0; ((pos < (blen*2)) && (pos < strlen(str))); pos += 2)
   {
      idx0 = (uint8_t)str[pos+0];
      idx1 = (uint8_t)str[pos+1];
      bytes[pos/2] = (uint8_t)(hashmap[idx0] << 4) | hashmap[idx1];
   };

   return(0);
}

