//
//  WidgetBridge.m
//  Amnesty
//
//  Created by Danny Espinoza on 4/25/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetBridge.h"
#import "WidgetCalculator.h"
#import "WidgetController.h"
#import "WidgetMenu.h"
#import "WidgetSystem.h"

#import <WebKit/WebKit.h>

@implementation WidgetBridge

- (id)initWithWebView:(WebView*)webview
{
	if(self = [super init]) {
#if defined(BuildBrowser)
		prefPath = nil;
		prefDict = nil;
#endif
		
		webView = (WidgetView*) webview;
		scriptObject = nil;
		controller = nil;

		identifier = [[NSString alloc] initWithString:@"amnesty"];
		
#if defined(BuildClient)
		NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
		if(infoPlist) {
			NSString* stamp = (NSString*) [infoPlist objectForKey:@"AmnestyClientStamp"];
			if(stamp) {
				identifier = [[NSString alloc] initWithFormat:@"%@", stamp];
			}
		}
#endif

		cleaner = nil;

		startuprequest = nil;
		calculator = nil;
		menu = nil;
		
		systemCalls = nil;
		undefined = nil;
		
		systemEndHandler = nil;
		systemOutputHandler = nil;
		systemErrorHandler = nil;

		onremove = nil;
		onhide = nil;
		onshow = nil;
		ondragstart = nil;
		ondragstop = nil;
		onreceiverequest = nil;
		
		onfocus = nil;
		onblur = nil;
	}
	
	return self;
}

- (void)dealloc
{
	AmnestyLog(@"bridge dealloc");
	
	[self endScripting];
	
	if(calculator)
		[calculator release];
		
	if(menu)
		[menu release];
	
#if defined(BuildBrowser)
	[prefPath release];
	[prefDict release];
#endif
	
	if(identifier)
		[identifier release];
				
	[super dealloc];
}

- (void)windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
{
	if(scriptObject == nil) {
		[windowScriptObject setValue:self forKey:@"widget"];
		
		scriptObject = [windowScriptObject retain];
	}
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if(aSelector == @selector(openURL:))
		return @"openURL";
		
	if(aSelector == @selector(openApplication:))
		return @"openApplication";
		
	if(aSelector == @selector(prepareForTransition:))
		return @"prepareForTransition";
		
	if(aSelector == @selector(preferenceForKey:))
		return @"preferenceForKey";
		
	if(aSelector == @selector(resizeAndMoveTo:withY:withWidth:withHeight:))
		return @"resizeAndMoveTo";
		
	if(aSelector == @selector(setPositionOffset:withY:))
		return @"setPositionOffset";
		
	if(aSelector == @selector(setCloseBoxOffset:withY:))
		return @"setCloseBoxOffset";
		
	if(aSelector == @selector(setPreferenceForKey:withKey:))
		return @"setPreferenceForKey";
		
	if(aSelector == @selector(system:withHandler:))
		return @"system";
			
	if(aSelector == @selector(alert:))
		return @"alert";
	
	AmnestyLog(@"selector not recognized %s", sel_getName(aSelector));
	
	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return NO;
}

+ (NSString *)webScriptNameForKey:(const char *)name
{
	return nil;
}

- (void)finalizeForWebScript
{
	AmnestyLog(@"bridge finalize");
	
	[self endScripting];
}

- (id)invokeDefaultMethodWithArguments:(NSArray *)args
{
	AmnestyLog(@"bridge default method");
	return nil;
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args
{
	AmnestyLog(@"bridge undefined method: %@", name);
	return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	AmnestyLog(@"set value %@ for %@", value, key);
	
	[super setValue:value forKey:key];
	
	if([key isEqualToString:@"onremove"])
		[onremove retain];
	
	if([key isEqualToString:@"onhide"])
		[onhide retain];
	
	if([key isEqualToString:@"onshow"])
		[onshow retain];
	
	if([key isEqualToString:@"ondragstart"])
		[ondragstart retain];
	
	if([key isEqualToString:@"ondragstop"])
		[ondragstop retain];
	
	if([key isEqualToString:@"onfocus"])
		[onfocus retain];
	
	if([key isEqualToString:@"onblur"])
		[onblur retain];
	
	if([key isEqualToString:@"onreceiverequest"])
		[onreceiverequest retain];
}

- (id)valueForKey:(NSString *)key
{
	if(scriptObject == nil)
		return nil;
		
	return [super valueForKey:key];
}

- (void)setController:(id)inController
{
	if(controller == nil) {
		controller = inController;
	}
}

- (void)enableUndefined
{
	if(scriptObject) {
		undefined = [[NSString alloc] initWithString:@""];
		[scriptObject setValue:undefined forKey: @"undefined"];
	}
}

- (void)enableCalculator
{
	if(calculator == nil) {
		calculator = [[WidgetCalculator alloc] init];
		[calculator setWebScriptObject: scriptObject];
	}
}

- (void)enableSystem
{
	if(systemCalls == nil)
		systemCalls = [[NSMutableArray alloc] initWithCapacity: 0];
}

- (void)cleanSystem:(id)sender
{
	if(systemCalls && [systemCalls count]) {
		NSMutableArray* cleanArray = nil;
		BOOL callsAreActive = NO;
		
		NSEnumerator* enumerator = [systemCalls objectEnumerator];
		WidgetSystem* anObject;
		long index = 0;
		
		while((anObject = [enumerator nextObject])) {
			if(anObject != (WidgetSystem*) [NSNull null]) {
				if([anObject readyToRelease] || [self findSystem:anObject withHash:[anObject getCommandHash] withCopies:2]) {
					if(cleanArray == nil)
						cleanArray = [[NSMutableArray alloc] initWithCapacity:[systemCalls count]];
						
					if(cleanArray)
						[cleanArray addObject:[NSNumber numberWithLong:index]];
				}
				
				callsAreActive = YES;
			}	
			
			index++;
		}
		
		if(cleanArray) {
			NSEnumerator* enumerator2 = [cleanArray objectEnumerator];
			NSNumber* anIndex;
			
			while((anIndex = [enumerator2 nextObject])) {
				index = [anIndex longValue];
				anObject = [systemCalls objectAtIndex:index];
				if(anObject != (WidgetSystem*) [NSNull null]) {
					[anObject retain];
					[systemCalls replaceObjectAtIndex:index withObject:[NSNull null]];
					[anObject shutdown];
					[anObject release];
				}
			}
			
			[cleanArray release];
		}
		else if(callsAreActive == NO) {
			[cleaner invalidate];
			cleaner = nil;

			[systemCalls release];
			systemCalls = [[NSMutableArray alloc] initWithCapacity: 0];
		}
	}
}		
		
- (BOOL)findSystem:(id)system withHash:(unsigned)hash withCopies:(unsigned)copies
{
	if(system && hash && copies) {
		unsigned matches = 0;
		BOOL start = NO;
		
		NSEnumerator* enumerator = [systemCalls objectEnumerator];
		WidgetSystem* anObject;

		while((anObject = [enumerator nextObject])) {
			if(start == NO) {
				if(anObject == system)
					start = YES;
				
				continue;
			}
			
			if(anObject != (WidgetSystem*) [NSNull null] && [anObject getCommandHash] == hash && [anObject isTerminated]) {
				if(++matches == copies)
					return YES;
			}
		}
	}
	
	return NO;
}
		
- (void)endScripting
{
	if(onremove) {
		[onremove release];
		onremove = nil;
	}
	
	if(onhide) {
		[onhide release];
		onhide = nil;
	}
	
	if(onshow) {
		[onshow release];
		onshow = nil;
	}
	
	if(ondragstart) {
		[ondragstart release];
		ondragstart = nil;
	}
	
	if(ondragstop) {
		[ondragstop release];
		ondragstop = nil;
	}

	if(onfocus) {
		[onfocus release];
		onfocus = nil;
	}

	if(onblur) {
		[onblur release];
		onblur = nil;
	}

	if(onreceiverequest) {
		[onreceiverequest release];
		onreceiverequest = nil;
	}

	if(cleaner) {
		[cleaner invalidate];
		cleaner = nil;
	}
	
	if(systemCalls) {
		NSEnumerator* enumerator = [systemCalls objectEnumerator];
		WidgetSystem* anObject;
		
		while((anObject = [enumerator nextObject])) {
			if(anObject != (WidgetSystem*) [NSNull null])
				[anObject shutdown];
		}
		
		[systemCalls release];
		systemCalls = nil;
	}
	
	if(undefined) {
		[undefined release];
		undefined = nil;
	}

	[scriptObject release];
	scriptObject = nil;
}

- (BOOL)canRemove
{
	return (onremove == nil ? NO : YES);
}

- (BOOL)canHide
{
	return (onhide == nil ? NO : YES);
}

- (BOOL)canShow
{
	return (onshow == nil ? NO : YES);
}

- (BOOL)canDragStart
{
	return (ondragstart == nil ? NO : YES);
}

- (BOOL)canDragStop
{
	return (ondragstop == nil ? NO : YES);
}

- (BOOL)canFocus
{
	return (onfocus == nil ? NO : YES);
}

- (BOOL)canBlur
{
	return (onblur == nil ? NO : YES);
}

- (void)loadPreferences:(NSString *)bundleID
{
#if defined(BuildBrowser)
	prefPath = [[NSString alloc] initWithFormat:@"%@/Library/Application Support/Amnesty/Preferences/%@.plist", NSHomeDirectory(), bundleID];
	
	NSString* path = prefPath;
	
	NSString* oldPrefPath = [NSString stringWithFormat:@"%@/Library/Application Support/Amnesty/Preferences/%@", NSHomeDirectory(), bundleID];
	NSFileManager* fm = [NSFileManager defaultManager];
	if([fm fileExistsAtPath:prefPath] == NO) {
		if([fm fileExistsAtPath:oldPrefPath])
			path = oldPrefPath;
		else
			path = nil;
	}
	else {
		if([fm fileExistsAtPath:oldPrefPath])
			[fm removeFileAtPath:oldPrefPath handler:nil];
	}

	if(path) {
		NSString* error = nil;
		NSData* data = [NSData dataWithContentsOfFile:path];
		prefDict = (NSMutableDictionary*) [NSPropertyListSerialization propertyListFromData:data
												 mutabilityOption:NSPropertyListMutableContainersAndLeaves
														   format:nil
												 errorDescription:&error];
		
		if(error) {
			NSLog(@"Error deserializing %@: %@", path, error);
			[error release];
		}
		
		if(prefDict)
			[prefDict retain];
	}
	
	if(prefDict == nil)
		prefDict = [[NSMutableDictionary alloc] init];
/*
	prefPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFStringRef) NSHomeDirectory());
	
	if(prefPath) {
		CFStringAppend(prefPath, CFSTR("/Library/Application Support/Amnesty/Preferences/"));
		CFStringAppend(prefPath, (CFStringRef) bundleID);
		CFStringAppend(prefPath, CFSTR(".plist"));

		NSString *path = (NSString*) prefPath; // Assume this is a path to a valid plist.
		NSData *plistData;
		NSString *error;
		NSPropertyListFormat format;
		id plist;
		plistData = [NSData dataWithContentsOfFile:path];
		plist = [NSPropertyListSerialization propertyListFromData:plistData
			mutabilityOption:NSPropertyListImmutable
			format:&format
			errorDescription:&error];

		if(!plist) {
			//NSLog(error);
			[error release];
			
			prefDict = CFDictionaryCreateMutable(
				kCFAllocatorDefault,
				0,
				&kCFTypeDictionaryKeyCallBacks,
				&kCFTypeDictionaryValueCallBacks);
		}
		else {
			prefDict = CFDictionaryCreateMutableCopy(
				kCFAllocatorDefault,
				0,
				(CFDictionaryRef) plist);
		}
	}
*/
#endif	
}

- (void)savePreferences
{
#if defined(BuildBrowser)
	if(prefPath && prefDict) {
		NSString* error = nil;
		NSData* data = [NSPropertyListSerialization dataFromPropertyList:prefDict format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];

		if(error) {
			NSLog(@"Error serializing write %@: %@", prefPath, error);
			[error release];
		}

		if(data) {
			if([data writeToFile:prefPath atomically:YES] == NO)
				NSLog(@"Error writing  %@.", prefPath);
		}
	}
	
/*	
	if(prefPath && prefDict && CFDictionaryGetCount(prefDict)) {
		id plist = (id) prefDict;       // Assume this exists.
		NSString *path = (NSString*) prefPath; // Assume this is a valid path.
		NSData *xmlData;
		NSString *error;
		xmlData = [NSPropertyListSerialization dataFromPropertyList:plist
											   format:NSPropertyListBinaryFormat_v1_0
											   errorDescription:&error];
		if(xmlData)
		{
			[xmlData writeToFile:path atomically:YES];
		}
		else
		{
			//NSLog(error);
			[error release];
		}
	}
*/
#elif defined(BuildClient)
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
#endif
}

/* methods */

- (id) preferenceForKey:(NSString *)key
{
#if defined(BuildBrowser)
	return [prefDict objectForKey:key];
	
	/*
	if(prefDict) {
		NSString* outPreference = (NSString*) CFDictionaryGetValue(prefDict, key);
		if(outPreference)
			return outPreference;
	}
	 */
#elif defined(BuildClient)
	return (id) CFPreferencesCopyAppValue((CFStringRef) key, kCFPreferencesCurrentApplication);
#endif
	
	return NULL;
}

- (void) setPreferenceForKey:(id)preference withKey:(NSString *)key
{
#if defined(BuildBrowser)
	if(preference)
		[prefDict setObject:preference forKey:key];
	else
		[prefDict removeObjectForKey:key];
	
/*	if(prefDict) {
		if(preference == NULL)
			CFDictionaryRemoveValue(prefDict, key);
		else	
			CFDictionarySetValue(prefDict, key, preference);
	}
 */
#elif defined(BuildClient)
	CFPreferencesSetAppValue((CFStringRef) key, (CFPropertyListRef) preference, kCFPreferencesCurrentApplication);	
#endif	
}

- (void)openURL:(NSString*)url
{
	CFURLRef target = CFURLCreateWithString(nil, (CFStringRef) url, nil);
	if(target == nil) {
		CFStringRef escapedURL = CFURLCreateStringByAddingPercentEscapes(nil, (CFStringRef)url, nil, nil, kCFStringEncodingUTF8);
		target = CFURLCreateWithString(nil, (CFStringRef) escapedURL, nil);
		CFRelease(escapedURL);
	}

	if(target) {
		LSOpenCFURLRef((CFURLRef) target, nil);
		CFRelease(target);
	}
}

- (void)openApplication:(NSString*)bundleID
{
	FSRef ref;
	if(LSFindApplicationForInfo(kLSUnknownCreator, (CFStringRef) bundleID, nil, &ref, nil) == noErr)
		LSOpenFSRef(&ref, nil);
}

- (void)prepareForTransition:(NSString*)name
{
	BOOL toBack = ([name compare:@"ToBack" options:NSCaseInsensitiveSearch] == NSOrderedSame ? YES : NO);
	[controller startTransition:toBack];
}

- (void)performTransition
{
	[controller endTransition];
}

- (id)system:(NSString *)command withHandler:(id)handler
{
	if(controller && systemCalls) {
		if(cleaner == nil)
			cleaner = [NSTimer
				scheduledTimerWithTimeInterval: (double) 10.0
				target: self
				selector:@selector(cleanSystem:)
				userInfo: nil
				repeats: YES];
		
		WidgetSystem* system = [[WidgetSystem alloc] init];
		[systemCalls addObject: system];
		[system release];
		
#if defined(BuildClient)
		NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
		if(infoPlist) {
			NSString* clientID = (NSString*) [infoPlist objectForKey:@"AmnestyClientID"];
			if(clientID) {
				NSString* shellID = [[NSString alloc] initWithFormat:@"%@", clientID];
				[system setShellID:shellID];
				[shellID release];
			}
		}
#endif
	
		[system setWebScriptObject: scriptObject];

		if(handler == nil) {
			[system execute: command withPath:[controller getWidgetPath] andWait:YES];
		}
		else {
			[system setEndHandler: handler];
			[system execute: command withPath:[controller getWidgetPath] andWait:NO];		
		}
						
		return system;
	}
	
	return nil;
}

/* undocumented */

- (void)resizeAndMoveTo:(int)x withY:(int)y withWidth:(int)width withHeight:(int)height
{
	if(controller) {
		NSScreen* screen = [[controller window] screen];
		NSRect screenFrame = [screen frame];
		
		NSRect windowFrame = [[controller window] frame];
		//NSLog(@"%.0f %d", windowFrame.size.height, height);
				
		windowFrame.origin.x = x;
		windowFrame.origin.y = screenFrame.size.height - (y + height);
		windowFrame.size.width = width;
		windowFrame.size.height = height;
		
		[[controller window] setFrame: windowFrame display: YES animate:NO];
		[controller redraw];
	}
}

- (void)setPositionOffset:(int)x withY:(int)y
{
}

- (void)setCloseBoxOffset:(int)x withY:(int)y
{
}

- (id)createMenu
{	
	if(menu) {
		[menu release];
		menu = nil;
	}

	if(controller) {
		menu = [[WidgetMenu alloc] init];
		[menu setWindow: [controller window]];
	}
	
	return menu;
}

- (id)closestCity
{
	return nil;
}

- (void)alert:(NSString*)message
{
	NSLog(@"%@", message);
}

@end
