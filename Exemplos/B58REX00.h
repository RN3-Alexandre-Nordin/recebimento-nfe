 
/***************************************************************************** 
 *    Header File:  B58REX00.h 
 * 
 *    Description:  Converte Data Header File 
 * 
 *        History: 
 *          Date        Programmer  SAR# - Description 
 *          ----------  ----------  ------------------------------------------- 
 *   Author 18/04/26    FOURC       Unknown  - Created  
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
 
#ifndef __B58REX00_H
#define __B58REX00_H 
 
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
 JDEBFRTN (ID) JDEBFWINAPI ConvertISODateToJDEFormat        (LPBHVRCOM lpBhvrCom, LPVOID lpVoid, LPDSD58REX001 lpDS); 
 
 
/***************************************************************************** 
 * Internal Function Prototypes 
 ****************************************************************************/ 
 
#endif    /* __B58REX00_H */ 
 
