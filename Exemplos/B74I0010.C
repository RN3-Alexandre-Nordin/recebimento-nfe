#include <jde.h>

#define b74i0010_c


/*****************************************************************************
 *    Source File:  b74i0010
 *
 *    Description:  Convert String to Date Format Mask Source File
 *
 *        History:
 *          Date        Programmer  SAR# - Description
 *          ----------  ----------  -------------------------------------------
 *   Author 8/11/98                 2270901  - Created  
 *
 * Copyright (c) J.D. Edwards World Source Company, 1996
 *
 * This unpublished material is proprietary to J.D. Edwards World Source Company.
 * All rights reserved.  The methods and techniques described herein are
 * considered trade secrets and/or confidential.  Reproduction or
 * distribution, in whole or in part, is forbidden except by express
 * written permission of J.D. Edwards World Source Company.
 ****************************************************************************/
/**************************************************************************
 * Notes:
 *
 **************************************************************************/

#include <b74i0010.h>


/**************************************************************************
 *  Business Function:  ConvertStringToDateUsingMask
 *
 *        Description:  Convert String to Date Using Format Mask
 *
 *         Parameters:
 *           LPBHVRCOM           lpBhvrCom    Business Function Communications
 *           LPVOID              lpVoid       Void Parameter - DO NOT USE!
 *           LPDSD74I0010        lpDS         Parameter Data Structure Pointer  
 *
 *************************************************************************/

JDEBFRTN (ID) JDEBFWINAPI ConvertStringToDateUsingMask (LPBHVRCOM lpBhvrCom, LPVOID lpVoid, LPDSD74I0010 lpDS)  
{
   /************************************************************************
    *  Variable declarations
    ************************************************************************/

   /************************************************************************
    * Declare structures
    ************************************************************************/

   /************************************************************************
    * Declare pointers
    ************************************************************************/

   /************************************************************************
    * Check for NULL pointers
    ************************************************************************/
   if ((lpBhvrCom == (LPBHVRCOM) NULL) ||
       (lpVoid    == (LPVOID)    NULL) ||
       (lpDS      == (LPDSD74I0010)	NULL))
   {
     jdeErrorSet (lpBhvrCom, lpVoid, (ID) 0, _J("4363"), (LPVOID) NULL);
     return ER_ERROR;
   }

   /************************************************************************
    * Set pointers
    ************************************************************************/

   /************************************************************************
    * Main Processing
    ************************************************************************/
	DeformatDate(&lpDS->ConvertedDate, 
		         lpDS->StringToConvert, 
				 lpDS->FormatMask);

   /************************************************************************
    * Function Clean Up
    ************************************************************************/

   return (ER_SUCCESS);
}

/* Internal function comment block */
/**************************************************************************
 *   Function:  Ixxxxxxx_a   // Replace "xxxxxxx" with source file number
 *                           // and "a" with the function name
 *      Notes:
 *
 *    Returns:
 *
 * Parameters:
 **************************************************************************/

