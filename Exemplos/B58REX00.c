#include <jde.h> 
 
#define b58rex00_c 
 
 
/***************************************************************************** 
 *    Source File:  b58rex00 
 * 
 *    Description:  Converte Data Source File 
 * 
 *        History: 
 *          Date        Programmer  SAR# - Description 
 *          ----------  ----------  ------------------------------------------- 
 *   Author 18/04/26    FOURC       Unknown  - Created   
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
 
#include <b58rex00.h> 
 
 
/************************************************************************** 
 *  Business Function:  ConvertISODateToJDEFormat 
 * 
 *        Description:  Converts ISO 8601 to JDE Date 
 * 
 *         Parameters: 
 *           LPBHVRCOM           lpBhvrCom    Business Function Communications 
 *           LPVOID              lpVoid       Void Parameter - DO NOT USE! 
 *           LPDSD58RE           lpDS         Parameter Data Structure Pointer   
 * 
 *************************************************************************/ 
 
JDEBFRTN (ID) JDEBFWINAPI ConvertISODateToJDEFormat (LPBHVRCOM lpBhvrCom, LPVOID lpVoid, LPDSD58REX001 lpDS)  
 
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
       (lpDS      == (LPDSD58REX001)	NULL)) 
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

