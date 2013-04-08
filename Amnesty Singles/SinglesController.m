//
//  SinglesController.m
//  Amnesty Singles
//
//  Created by Danny Espinoza on 4/4/06.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#import "SinglesController.h"

#import "IconFamily.h"

#include "CWidget.h"
#include "WidgetUtilities.h"

@implementation SinglesController

- (NSString *)windowNibName
{
    return @"MainMenu";
}

- (void)awakeFromNib
{	
	[NSApp setDelegate:self];
		
	[drop unregisterDraggedTypes];
	
#if defined(WidgetPopupMenu)
	[self openAmnesty];	
	[self populateMenu];
#endif
    
    [loadInternal setEnabled:YES];

	[theAbout setLevel: NSStatusWindowLevel+1];
 	[theAbout center];
	
	[self readPreferences];
}

- (IBAction)handleFindOnDisk:(id)sender
{
	{
		NSMutableString* localWidgetString = [NSMutableString stringWithCapacity: 1024];
		[localWidgetString appendString: NSHomeDirectory()];
		[localWidgetString appendString: @"/Library/Widgets"];
	    
        NSURL* target = [NSURL fileURLWithPath: localWidgetString];
        if(target)
            LSOpenCFURLRef((CFURLRef) target, NULL);
    }
    
	{
		NSMutableString* systemWidgetString = [NSMutableString stringWithCapacity: 1024];
		[systemWidgetString appendString: NSOpenStepRootDirectory()];
		[systemWidgetString appendString: @"Library/Widgets"];
	    
        NSURL* target = [NSURL fileURLWithPath: systemWidgetString];
        if(target)
            LSOpenCFURLRef((CFURLRef) target, NULL);
    }
}

- (IBAction)handleAdd:(id)sender
{
}

- (IBAction)handleRemove:(id)sender
{
}

- (IBAction)handleAdvanced:(id)sender
{
	[NSApp beginSheet: advPanel
		modalForWindow: [self window]
		modalDelegate: nil
		didEndSelector: nil 
		contextInfo: nil];

	[NSApp runModalForWindow: advPanel];
	
	[NSApp endSheet: advPanel];
	[advPanel orderOut: self];
}

- (IBAction)handleClose:(id)sender
{
	[NSApp stopModal];
}

- (IBAction)handleBuild:(id)sender
{
	NSString* widgetPath;
	
	if([loadInternal intValue] == YES)
		widgetPath = [[location stringValue] lastPathComponent];
	else
		widgetPath = [location stringValue];
	
	NSString* widgetName = [name stringValue];
	
	NSSavePanel* savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView:saveExtra];
	[savePanel beginSheetForDirectory:nil file:widgetName modalForWindow:[self window] modalDelegate:(id)self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{	
	if(returnCode == NSFileHandlingPanelOKButton) {
		NSString* singleStamp = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSinceReferenceDate]];
		
		NSString* amnestyClient = [NSString stringWithFormat:@"%@/AmnestyClient.app", [[NSBundle mainBundle] resourcePath]];
		NSString* singleTemp = [NSString stringWithFormat:@"%@.app", [sheet filename]];
		NSString* singleLocation = [singleTemp stringByDeletingLastPathComponent];
		NSString* singleName = [singleTemp lastPathComponent];
		//NSString* singleTemp = [NSString stringWithFormat:@"%@/%@.app", NSTemporaryDirectory(), singleStamp];
				
		NSString* widgetPath = [location stringValue];
		NSString* widgetFileName = [widgetPath lastPathComponent];
		NSString* embedded = [NSString stringWithFormat:@"%@/Contents/Resources/%@", singleTemp, widgetFileName];
		NSString* icns = [NSString stringWithFormat:@"%@/Contents/Resources/%@.icns", singleTemp, widgetFileName];
		NSString* oldIcns = [NSString stringWithFormat:@"%@/Contents/Resources/AmnestyClient.icns", singleTemp];
		
		if([[NSFileManager defaultManager] fileExistsAtPath:singleTemp]) {
			NSAlert* alert = nil;

			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ReplaceTitle", @"")
				defaultButton: NSLocalizedString(@"ReplaceOK", @"")
				alternateButton: NSLocalizedString(@"ReplaceCancel", @"")
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"ConfirmReplace", @""), singleName];

			[NSApp activateIgnoringOtherApps: YES];
			[[alert window] setLevel: NSStatusWindowLevel+1];
			if([alert runModal] == 0) {
				return;
			}

			[[NSFileManager defaultManager] removeFileAtPath:singleTemp handler:nil];
		}
		
		if([[NSFileManager defaultManager] copyPath:amnestyClient toPath:singleTemp handler:nil] == YES) {
			NSString* path = [NSString stringWithFormat:@"%@/Contents/Info.plist", singleTemp];
			NSData* plistData = [NSData dataWithContentsOfFile:path];
			
			NSString* error;
			NSPropertyListFormat format;
			id plist = [NSPropertyListSerialization propertyListFromData:plistData
				mutabilityOption:NSPropertyListImmutable
				format:&format
				errorDescription:&error];
				
			if(plist) {
				CFMutableDictionaryRef prefDict = CFDictionaryCreateMutableCopy(
					kCFAllocatorDefault,
					0,
					(CFDictionaryRef) plist);

				//NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
				//[dateFormatter setDateStyle:NSDateFormatterNoStyle];
				//[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				
				CFDictionarySetValue(prefDict, CFSTR("CFBundleName"), [name stringValue]);
				CFDictionarySetValue(prefDict, CFSTR("CFBundleShortVersionString"), [version stringValue]);
				CFDictionarySetValue(prefDict, CFSTR("CFBundleIconFile"), [NSString stringWithFormat:@"%@.icns", widgetFileName]);
	
				CFDictionarySetValue(prefDict, CFSTR("CFBundleIdentifier"), [NSString stringWithFormat:@"single-%@", [identifier stringValue]]);
				
				CFDictionarySetValue(prefDict, CFSTR("AmnestyClientStamp"), singleStamp);
                
				if([loadInternal intValue] == YES)
					CFDictionarySetValue(prefDict, CFSTR("AmnestyClientPath"), widgetFileName);
				else
					CFDictionarySetValue(prefDict, CFSTR("AmnestyClientPath"), [location stringValue]);
                
				CFDictionarySetValue(prefDict, CFSTR("AmnestyClientID"), [identifier stringValue]);
				
				// if the widget has a PPC architecture plugin force the single to run under Rosetta
				if(isUniversal == NO) {
					NSNumber* rosetta = [NSNumber numberWithBool:YES];
					CFDictionarySetValue(prefDict, CFSTR("LSPrefersPPC"), rosetta);
				}
				
				plist = (id) prefDict;	
					
				NSData* xmlData = [NSPropertyListSerialization dataFromPropertyList:plist
					format:NSPropertyListXMLFormat_v1_0
					errorDescription:&error];
					
				if(xmlData)
					[xmlData writeToFile:path atomically:YES];
			}
			
			{
				NSImage* image = [[preview image] copy];
				IconFamily* iconFamily = [IconFamily iconFamilyWithThumbnailsOfImage:image usingImageInterpolation:NSImageInterpolationHigh];					
				[iconFamily writeToFile:icns];
			}
			
			[[NSFileManager defaultManager] removeFileAtPath:oldIcns handler:nil];
			
			if([loadInternal intValue] == YES)
				[[NSFileManager defaultManager] copyPath:widgetPath toPath:embedded handler:nil];

			//if([[NSFileManager defaultManager] copyPath:singleTemp toPath:singleApp handler:nil] == YES) {
				//[[NSFileManager defaultManager] removeFileAtPath:singleTemp handler:nil];

				LSRegisterURL((CFURLRef) [sheet URL], true);

				if([saveReveal intValue] == YES) {
					NSURL* target = [NSURL fileURLWithPath: singleLocation];
					if(target)
						LSOpenCFURLRef((CFURLRef) target, NULL);
				}
				
				if([saveLaunch intValue] == YES) {
					NSURL* target = [NSURL fileURLWithPath: singleTemp];
					if(target)
						LSOpenCFURLRef((CFURLRef) target, NULL);
				}
			
			[[self window] orderOut:self];

			//}
		}	
	}
}

- (IBAction)handleHelp:(id)sender
{
}

- (IBAction)handleAbout:(id)sender
{
	[theAbout display];
	[theAbout makeKeyAndOrderFront: sender];	

	[NSApp activateIgnoringOtherApps: YES];
}

- (void)setWidgetFromURL:(NSURL*)url
{
	CFStringRef urlPath = CFURLCopyFileSystemPath((CFURLRef) url, kCFURLPOSIXPathStyle);
	[self setWidgetFromPath:(NSString*)urlPath];
	CFRelease(urlPath);
}

- (void)setWidgetFromPath:(NSString*)urlPath
{
	CWidget* widget = new CWidget((CFStringRef) urlPath);
	if(widget->IsValid() == false) {
		NSAlert* alert = nil;

		alert = [NSAlert alertWithMessageText: NSLocalizedString(@"CorruptTitle", @"")
			defaultButton: NSLocalizedString(@"GenericOK", @"")
			alternateButton: nil
			otherButton: nil
			informativeTextWithFormat: NSLocalizedString(@"CorruptMessage", @"")];

		[NSApp activateIgnoringOtherApps: YES];
		[[alert window] setLevel: NSStatusWindowLevel+1];
		[alert runModal];

		delete widget;
		return;
	}

	widget->Core();

	if(widget->IsValid() == false) {
		NSAlert* alert = nil;
		
		if(widget->IsForbidden()) {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"NoSupportTitle", @"")
				defaultButton: NSLocalizedString(@"GenericOK", @"")
				alternateButton: nil
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"NoSupportPantherMessage", @"")];
		}
		else {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"NoSupportTitle", @"")
				defaultButton: NSLocalizedString(@"GenericOK", @"")
				alternateButton: nil
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"NoSupportMessage", @"")];
		}		

		[NSApp activateIgnoringOtherApps: YES];
		[[alert window] setLevel: NSStatusWindowLevel+1];
		[alert runModal];

		delete widget;
		return;
	}

	if([drop isHidden] == NO) {
		[drop setHidden: YES];
		[widgetInfo setHidden: NO];
		[singleInfo setHidden: NO];
		
		[build setEnabled: YES];
		
		[info setStringValue: NSLocalizedString(@"Instructions", @"")];
	}

	NSImage* icon = nil;
	NSURL* imageURL = (NSURL*) widget->GetIconURL();
	if(imageURL)
		icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
	
	if(icon == nil) {
		imageURL = (NSURL*) widget->GetImageURL();
		icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
	}
	
	if(icon) {
		NSSize imageSize = [icon size];
		NSImageRep* rep = [[icon representations] objectAtIndex: 0];
		NSSize actualSize;
		actualSize.width = (rep ? [rep pixelsWide] : imageSize.width);
		actualSize.height = (rep ? [rep pixelsHigh] : imageSize.height);
		[icon setSize:actualSize];

		[preview setImage: icon];
	}
		
	[name setStringValue:(NSString*) widget->GetName()];
	[identifier setStringValue:(NSString*) widget->GetID()];
	[version setStringValue:(NSString*) widget->GetVersion()];
	[location setStringValue:(NSString*) urlPath];
	
	delete widget;

	// test Universality for any dependent Widget or WebKit plugins
	isUniversal = YES;
	
	NSArray* resources = [[NSFileManager defaultManager] directoryContentsAtPath:urlPath];
	if(resources) {
		NSEnumerator* enumerator = [resources objectEnumerator];
		NSString* file;
	
		while(isUniversal == YES && (file = [enumerator nextObject])) {
			if(
				[[file pathExtension] isEqualToString: @"widgetplugin"] ||
				[[file pathExtension] isEqualToString: @"plugin"] ||
				[[file pathExtension] isEqualToString: @"bundle"] ||
				[[file pathExtension] isEqualToString: @"webplugin"]
			) {
				extern bool BundleArchitectureIsIntel(CFStringRef inBundlePath);
				
				NSString* fullPath = [urlPath stringByAppendingPathComponent:file];
				if(!BundleArchitectureIsIntel((CFStringRef) fullPath)) {
					isUniversal = NO;
				}
			}
		}
	}
	
	[NSApp activateIgnoringOtherApps: YES];
}

- (void)readPreferences
{
	NSNumber* setting = nil;
	
	setting = (NSNumber*) CFPreferencesCopyAppValue(CFSTR("SaveReveal"), kCFPreferencesCurrentApplication);
	if(setting)
		[saveReveal setState: [setting intValue]];
		
	setting = (NSNumber*) CFPreferencesCopyAppValue(CFSTR("SaveLaunch"), kCFPreferencesCurrentApplication);
	if(setting)
		[saveLaunch setState: [setting intValue]];
}

- (void)writePreferences
{
	CFPreferencesSetAppValue(CFSTR("SaveReveal"), [NSNumber numberWithInt: [saveReveal state]], kCFPreferencesCurrentApplication);	
	CFPreferencesSetAppValue(CFSTR("SaveLaunch"), [NSNumber numberWithInt: [saveLaunch state]], kCFPreferencesCurrentApplication);	
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

// NSApplication delegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	[[self window] center];
	[[self window] makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification* )aNotification
{
	[self writePreferences];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fileName
{
	if([fileName hasSuffix: @".wdgt"]) {
		[self setWidgetFromPath:fileName];
		return YES;
	}
	
	return NO;
}

@end
