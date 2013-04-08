/*
 *  WidgetUtilities.c
 *  Amnesty
 *
 *  Created by Danny Espinoza on Sat Apr 23 2005.
 *  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include "WidgetUtilities.h"
#include "CWidget.h"

#if defined(FeaturePanther)
static Boolean FSCountWidgets(
		Boolean containerChanged,
		ItemCount currentLevel,
		const FSCatalogInfo *catalogInfo,
		const FSRef *ref,
		const FSSpec *spec,
		const HFSUniStr255 *name,
		void *yourDataPtr);

long CountWidgets(
	CFStringRef inURL,
	long inMaxLevels)
{
	FSRef ref;
	Boolean foundDirectory = false;
	long widgetCount = 0;
	
	if(inURL) {
		UInt8 widgetPath[1024];
		Boolean isDirectory;

		CFStringGetCString(inURL, (char*) widgetPath, 1024, kCFStringEncodingUTF8);
		
		if(FSPathMakeRef(widgetPath, &ref, &isDirectory) == noErr && isDirectory)
			foundDirectory = true;
	}
	
	if(foundDirectory)
		FSIterateContainer(&ref, inMaxLevels, kFSCatInfoNodeFlags, false, true, (IterateContainerFilterProcPtr) FSCountWidgets, (void*) &widgetCount);
    
	return widgetCount;
}

Boolean FSCountWidgets(
                       Boolean containerChanged,
                       ItemCount currentLevel,
                       const FSCatalogInfo *catalogInfo,
                       const FSRef *ref,
                       const FSSpec *spec,
                       const HFSUniStr255 *name,
                       void *yourDataPtr)
{
	if(catalogInfo && (0 != (kFSNodeIsDirectoryMask & catalogInfo->nodeFlags)) && ref && name) {
		CFStringRef fileString = CFStringCreateWithCharacters(kCFAllocatorDefault, name->unicode, name->length);
		if(fileString) {
			if(CFStringHasSuffix(fileString, CFSTR(".wdgt"))) {
				UInt8 widgetPath[1024];
				if(FSRefMakePath(ref, widgetPath, 1024) == noErr) {
					CFStringRef pathString = CFStringCreateWithCString(kCFAllocatorDefault, (const char*) widgetPath, kCFStringEncodingUTF8);
					if(pathString) {
						long* count = (long*) yourDataPtr;
						(*count)++;
					}
				}
			}
            
			CFRelease(fileString);
		}
	}
	
	return false;
}
#endif

void FindWidgets(
	CFStringRef inURL,
	long inMaxLevels)
{
    CWidgetList* list = CWidgetList::GetInstance();

    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:(NSString*)inURL];
    Boolean enforceLevels = ([enumerator respondsToSelector:@selector(level)] ? YES : NO);
    
    for(NSString* path in enumerator) {
        if(enforceLevels && [(id)enumerator level] > inMaxLevels)
            continue;

        if([path hasSuffix:@".wdgt"]) {
            NSString* pathString = [NSString stringWithFormat:@"%@/%@", (NSString*)inURL, path];
            list->AddWidget(new CWidget((CFStringRef)pathString));
        }
    }
}

void
FindPlugins(
	CFStringRef inURL,
	bool inInstall)
{    
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:(NSString*)inURL];
    BOOL enforceLevels = ([enumerator respondsToSelector:@selector(level)] ? YES : NO);
    
    NSString* mainBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Plug-Ins"];
    
    for(NSString* path in enumerator) {
        if(enforceLevels && [(id)enumerator level] > 1)
            continue;
        
        if([path hasSuffix:@".plugin"] || [path hasSuffix:@".bundle"] || [path hasSuffix:@".webplugin"]) {
            NSString* pathString = [NSString stringWithFormat:@"%@/%@", (NSString*)inURL, path];
            
            NSString* pluginPath = [NSString stringWithFormat:@"%@/%@", mainBundlePath, path];
            [[NSFileManager defaultManager] removeFileAtPath:pluginPath handler:nil];

            if([[NSFileManager defaultManager] createSymbolicLinkAtPath:pluginPath pathContent:pathString] == YES) {
                pluginPath = [NSString stringWithFormat:@"%@/Library/Internet Plug-Ins/Amnesty_%@", NSHomeDirectory(), path];

                [[NSFileManager defaultManager] removeFileAtPath:pluginPath handler:nil];
                [[NSFileManager defaultManager] createSymbolicLinkAtPath:pluginPath pathContent:pathString];
            }
        }
    }
}

void
FindWorkspaces(
	CFStringRef inURL,
	NSMutableArray* inArray)
{
	if(inArray == NULL)
		return;
	
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:(NSString*)inURL];
    Boolean enforceLevels = ([enumerator respondsToSelector:@selector(level)] ? YES : NO);
    
    for(NSString* path in enumerator) {
        if(enforceLevels && [(id)enumerator level] > 1)
            continue;
        
        if([path hasPrefix:@"com.mesadynamics.AmnestyWidgets."] && [path hasSuffix:@".plist"] && [path isEqualToString: @"com.mesadynamics.AmnestyWidgets.plist"] == NO) {
            [inArray addObject:path];
       }
    }
}

bool
CreateApplicationSupportFolders()
{
	bool installSamples = false;
	
	SInt16 theVRef;
	SInt32 theDirID;
	
	if(FindFolder(kUserDomain, kApplicationSupportFolderType, true, &theVRef, &theDirID) == noErr) {
        NSFileManager* fm = [NSFileManager defaultManager];
        NSString* libraryFolder = [NSString stringWithFormat:@"%@/Library/Application Support/Amnesty", NSHomeDirectory()];
        if([fm fileExistsAtPath:libraryFolder] == NO)
            [fm createDirectoryAtPath:libraryFolder attributes:nil];
        
        NSString* prefsFolder = [NSString stringWithFormat:@"%@/Library/Application Support/Amnesty/Preferences", NSHomeDirectory()];
        if([fm fileExistsAtPath:prefsFolder] == NO)
            [fm createDirectoryAtPath:prefsFolder attributes:nil];
        
        NSString* widgetsFolders = [NSString stringWithFormat:@"%@/Library/Application Support/Amnesty/Widgets", NSHomeDirectory()];
        if([fm fileExistsAtPath:widgetsFolders] == NO) {
            [fm createDirectoryAtPath:widgetsFolders attributes:nil];
            installSamples = true;
        }
	}
	
	return installSamples;
}
