/*
 *  WidgetUtilities.h
 *  Amnesty
 *
 *  Created by Danny Espinoza on Sat Apr 23 2005.
 *  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

#include <Carbon/Carbon.h>


#ifdef __cplusplus
extern "C" {
#endif

#if defined(FeaturePanther)
long CountWidgets(CFStringRef, long);
#endif
    
void FindWidgets(CFStringRef, long);
void FindPlugins(CFStringRef, bool);
void FindWorkspaces(CFStringRef, NSMutableArray*);

bool CreateApplicationSupportFolders();

#ifdef __cplusplus
}
#endif
