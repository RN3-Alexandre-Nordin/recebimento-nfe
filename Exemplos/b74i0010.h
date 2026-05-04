
/*****************************************************************************
 *    Header File:  B74I0010.h
 *
 *    Description:  Convert String to Date Format Mask Header File
 *
 *        History:
 *          Date        Programmer  SAR# - Description
 *          ----------  ----------  -------------------------------------------
 *   Author 8/11/98                 2270901  - Created  
 *
 *
 * Copyright (c) J.D. Edwards World Source Company, 1996
 *
 * This unpublished material is proprietary to J.D. Edwards World Source 
 * Company.  All rights reserved.  The methods and techniques described 
 * herein are considered trade secrets and/or confidential.  Reproduction
 * or distribution, in whole or in part, is forbidden except by express
 * written permission of J.D. Edwards World Source Company.
 ****************************************************************************/

#ifndef __B74I0010_H
#define __B74I0010_H

/*****************************************************************************
 * Table Header Inclusions
 ****************************************************************************/

/*****************************************************************************
 * External Business Function Header Inclusions
 ****************************************************************************/

/*****************************************************************************
 * Global Definitions
 ****************************************************************************/

/*****************************************************************************
 * Structure Definitions
 ****************************************************************************/

/*****************************************************************************
 * DS Template Type Definitions
 ****************************************************************************/
/*****************************************
 * TYPEDEF for Data Structure
 *    Template Name: Convert String to Date Format Mask
 *    Template ID:   D74I0010
 *    Generated:     Tue Aug 11 16:18:20 1998
 *
 * DO NOT EDIT THE FOLLOWING TYPEDEF
 *    To make modifications, use the Everest Data Structure
 *    Tool to Generate a revised version, and paste from
 *    the clipboard.
 *
 **************************************/

#ifndef DATASTRUCTURE_D74I0010
#define DATASTRUCTURE_D74I0010

typedef struct tagDSD74I0010
{
  JDEDATE           ConvertedDate;                       
  JCHAR              StringToConvert[11];                 
  JCHAR              FormatMask[10];                      
} DSD74I0010, *LPDSD74I0010;

#define IDERRConvertedDate_1                      1L
#define IDERRStringToConvert_2                    2L
#define IDERRFormatMask_3                         3L

#endif

/*****************************************************************************
 * Source Preprocessor Definitions
 ****************************************************************************/
#if defined (JDEBFRTN)
	#undef JDEBFRTN
#endif

#if defined (WIN32)
	#if defined (WIN32)
		#define JDEBFRTN(r) __declspec(dllexport) r
	#else
		#define JDEBFRTN(r) __declspec(dllimport) r
	#endif
#else
	#define JDEBFRTN(r) r
#endif

/*****************************************************************************
 * Business Function Prototypes
 ****************************************************************************/
JDEBFRTN (ID) JDEBFWINAPI ConvertStringToDateUsingMask     (LPBHVRCOM lpBhvrCom, LPVOID lpVoid, LPDSD74I0010 lpDS);


/*****************************************************************************
 * Internal Function Prototypes
 ****************************************************************************/

#endif    /* __B74I0010_H */

