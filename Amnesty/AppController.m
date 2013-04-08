//
//  AppController.m
//  Amnesty
//
//  Created by Danny Espinoza on Sat Apr 23 2005.
//  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "AppController.h"
#import "FileImageView.h"
#import "WidgetController.h"

#include "CFontList.h"
#include "CWidget.h"
#include "WidgetUtilities.h"
#include "UHotKeys.h"
#include "UBusy.h"

#include <sys/time.h>
#include <sys/resource.h>
	 
extern "C" UInt32 GetCurrentKeyModifiers();

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>

#import <IOKit/IOCFBundle.h>

enum {
	menuPreferences = -1,
	menuGuide = -2,
	menuFAQ = -3,
	menuIssues = -4,
	menuBringToFront = -5,
	menuPutBack = -6,
	menuSaveAs = -7,
	menuDelete = -8,
	menuCloseHidden = -9,
	menuToggle = -10,
	menuHints = -11,
	menuSettings = -12,
	menuGetMore = -13,
	menuAbout = -14,
	menuCheck = -15,
	menuIgnore = -99,
	menuSpaceNone = -100,
	menuSpaceDefault = -101,
	menuSpaceBase = -102,
	menuGroup = -1000
};

@implementation AppController

- (id)init
{
	if(self = [super init]) {
		statusItem = nil;
		
		opener = nil;
		
		workspace = menuSpaceDefault;
		savedWorkspace = workspace;
		
		theWorkspaces = nil;
		didSwitchWorkspace = NO;
		
		doSkipOpen = NO;
		doSkipWrite = NO;
		doSkipGuide = NO;
		didTryPurchase = NO;

		theBlotters = nil;
		blotterWorkspace = menuSpaceNone;
		
		theGroups = nil;
		
		enableFlip = YES;
		enableDrop = YES;

		root_port = IO_OBJECT_NULL;
		notifier = IO_OBJECT_NULL;
		notifyPortRef = NULL;
	}
	
	return self;
}

- (void)awakeFromNib
{
	[NSApp activateIgnoringOtherApps: YES];

#if 0
	// terminate if Amnesty already running
	ProcessSerialNumber own;
	if(GetCurrentProcess(&own) == noErr) {	
		ProcessSerialNumber psn = { kNoProcess, kNoProcess, };
		while(GetNextProcess(&psn) == noErr) {
			Boolean same;
			SameProcess(&psn, &own, &same);
			
			if(!same) {
				CFDictionaryRef dr = ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
				if(dr) {
					NSString* sr = (NSString*) CFDictionaryGetValue(dr, kIOBundleIdentifierKey);
					if([sr isEqualToString:@"com.mesadynamics.Amnesty"])
						[NSApp terminate: self];
				}
			}
		}
	}
#endif
	
	macVersion = 0;
	Gestalt(gestaltSystemVersion, &macVersion);
	
	// this should never happen
	if(macVersion < 0x1040) {
		NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"OldSystemTitle", @"")
			defaultButton: NSLocalizedString(@"OldSystemQuit", @"")
			alternateButton:nil
			otherButton:nil
			informativeTextWithFormat: NSLocalizedString(@"OldSystemMessage", @"")];

		[alert runModal];
		
		[NSApp terminate: self];
		return;
	}

	// check for modifiers here
	UInt32 modifiers = GetCurrentKeyModifiers();
	
	if((modifiers & (1<<9))) {
		doSkipOpen = YES;
		doSkipWrite = YES;
	}

	// force creation of the application support folder and install sample widgets
	bool installSamples = CreateApplicationSupportFolders();

	if(installSamples) {
		NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
		[amnestyWidgetString appendString: NSHomeDirectory()];
		[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];
		if(macVersion < 0x1040) {
			[[NSFileManager defaultManager] removeFileAtPath: amnestyWidgetString handler:nil];
		}
		else {
			[amnestyWidgetString appendString: @"/"];
			[amnestyWidgetString appendString: NSLocalizedString(@"Samples", @"")];
		}
		
		NSMutableString* amnestySampleString = [NSMutableString stringWithCapacity: 1024];
		[amnestySampleString appendString: [[NSBundle mainBundle] bundlePath]]; 
		[amnestySampleString appendString: @"/Contents/Samples"]; 
		
		[[NSFileManager defaultManager]
			copyPath: amnestySampleString
			toPath: amnestyWidgetString
			handler:nil];
	}

#if defined(FeaturePanther)
	if(macVersion < 0x1040) {
		NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
		[amnestyWidgetString appendString: NSHomeDirectory()];
		[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];
		
		long widgetCount = CountWidgets((CFStringRef) amnestyWidgetString, 0);
		//long widgetCount2 = 0;
		//NSLog(@"old %d, new %d", widgetCount, widgetCount2);
		
		if(widgetCount == 0) {
			NSString* message = [NSString stringWithFormat: @"%@\n\n%@ (%@).\n\n%@\n", 
				NSLocalizedString(@"PantherMessage1", @""),
				NSLocalizedString(@"PantherMessage2", @""),
				NSLocalizedString(@"PantherMessage3", @""),
				NSLocalizedString(@"PantherMessage4", @"")];
				
			NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"PantherTitle", @"")
				defaultButton: NSLocalizedString(@"PantherContinue", @"")
				alternateButton: NSLocalizedString(@"PantherInstall", @"")
				otherButton: NSLocalizedString(@"PantherQuit", @"")
				informativeTextWithFormat: @"%@", message];
				
			int alertResponse = [alert runModal];
			
			if(alertResponse < 1) {
				if(alertResponse == 0)
					[self openFolderAction: self];
					
				[NSApp terminate: self];
				return;
			}
		}
	}
#endif
    
	[thePreferences setLevel: NSStatusWindowLevel+1];
 	[thePreferences center];

	[theGuide setLevel: NSStatusWindowLevel-1];
 	[theGuide center];

	[theHints setLevel: NSStatusWindowLevel+1];
 	[theHints center];

	[theAbout setLevel: NSStatusWindowLevel+1];
 	[theAbout center];

	[thePurchase setLevel: NSStatusWindowLevel+1];
 	[thePurchase center];

	[theRegister setLevel: NSStatusWindowLevel+1];
 	[theRegister center];

	[self buildHotKeys];
	[self buildWorkspaces: YES];
	[self buildWorkspaceHotKeys: menuSpaceDefault andBind: YES];
	
	[self readPreferences];

	NSImage* guideImage = [[[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"Guide" ofType:@"png"]] autorelease];	
	[theGuideImage setImage: guideImage];

	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setMenu:theMenu];
	[statusItem setEnabled:YES];
	
	NSImage* image = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:(macVersion >= 0x1050 ? @"AmnestyLeo" : @"Amnesty") ofType:@"png"]] autorelease];
	[statusItem setImage:image];
	
	UBusy::SetStatusItem(statusItem);
	
	[theMenu setDelegate: self];
	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	[wm	setDelegate: self];
	
	[NSApp setDelegate: self];
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{    
	if(menu == theMenu) {
		NSWindow* modal = [NSApp modalWindow];
		if(modal) {
			[NSApp activateIgnoringOtherApps: YES];
			
			if(macVersion < 0x1050)
				[modal setLevel: NSStatusWindowLevel+1];
		}
	}
	
	//UInt32 modifiers = GetCurrentKeyModifiers();
	//[[NSCursor arrowCursor] set];

	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	
	if(menu != wm) {
		CWidgetList* list = CWidgetList::GetInstance();
		
#if 0
		for(unsigned long i = 1; i <= list->Size(); i++) {
			CWidget* widget = list->GetByIndex(i);
			if(widget) {
				NSMenuItem* menuItem = [menu itemWithTag: widget->GetSerial()];
			
				WidgetController* controller = (WidgetController*) widget->GetController();
				if(controller && [[controller window] isVisible])
					[menuItem setState: NSOnState];
				else {
					if(controller /*[controller busy]*/)
						[menuItem setState: NSMixedState];
					else
						[menuItem setState: NSOffState];
				}
			}
		}
#endif

		for(int i = 0; i < [menu numberOfItems]; i++) {
			NSMenuItem* menuItem = [menu itemAtIndex: i];
			int tag = [menuItem tag];
			
			if(tag > 0) {
				CWidget* widget = list->GetBySerial(tag);
				if(widget) {
					WidgetController* controller = (WidgetController*) widget->GetController();
					if(controller && [[controller window] isVisible]) {
                        [(WidgetWindow*)[controller window] nudge];
						[menuItem setState: NSOnState];
                    }
					else {
						if(controller) {
							//if([controller busy])
							//	[menuItem setMixedStateImage: [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"Loading" ofType:@"png"]]	];
							//else
							//	[menuItem setMixedStateImage:nil];
							
							[menuItem setState: NSMixedState];
						}
						else
							[menuItem setState: NSOffState];
					}
				}
			}
		}

		return;
	}
	
	if(workspace == menuSpaceDefault) {
		NSMenuItem* menuItem = [menu itemWithTag: menuSpaceDefault];
		[menuItem setState: NSOnState];
		menuItem = [menu itemWithTag: menuSpaceNone];
		[menuItem setState: NSOffState];

		int tag = menuSpaceBase;
		NSMenuItem* item = [menu itemWithTag: tag];
		while(item) {
			[item setState: NSOffState];
		
			tag--;
			item = [menu itemWithTag: tag];
		}
	}
	else if(workspace == menuSpaceNone) {
		NSMenuItem* menuItem = [menu itemWithTag: menuSpaceNone];
		[menuItem setState: NSOnState];
		menuItem = [menu itemWithTag: menuSpaceDefault];
		[menuItem setState: NSOffState];

		int tag = menuSpaceBase;
		NSMenuItem* item = [menu itemWithTag: tag];
		while(item) {
			[item setState: NSOffState];
		
			tag--;
			item = [menu itemWithTag: tag];
		}
	}
	else {
		NSMenuItem* menuItem = [menu itemWithTag: menuSpaceDefault];
		[menuItem setState: NSOffState];
		menuItem = [menu itemWithTag: menuSpaceNone];
		[menuItem setState: NSOffState];

		int tag = menuSpaceBase;
		NSMenuItem* item = [menu itemWithTag: tag];
		while(item) {
			if(workspace == [item tag])
				[item setState: NSOnState];
			else
				[item setState: NSOffState];
		
			tag--;
			item = [menu itemWithTag: tag];
		}
	}

	//NSMenuItem* item = [theMenu itemAtIndex: 0];
	//NSMenu* wm = [item submenu];
	
	if(item) {
		NSMenuItem* showHide = [menu itemWithTag: menuToggle];
		NSMenuItem* configure = [menu itemWithTag: menuHints];
		
		if(workspace == menuSpaceNone) {
			if(savedWorkspace != menuSpaceNone) {
				item = [wm itemWithTag: savedWorkspace];
				if(item)
					[showHide setTitle: [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"ShowWidgets", @""), [item title]]];
			}
			else
				[showHide setTitle: [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"ShowWidgets", @""), NSLocalizedString(@"DefaultLayout", @"")]];

			[configure setTitle: NSLocalizedString(@"ConfigureHidden", @"")];
		}
		else {
			item = [wm itemWithTag: workspace];
			if(item) {
				[showHide setTitle: [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"HideWidgets", @""), [item title]]];
				
				[configure setTitle: [NSString stringWithFormat: @"%@ %@...", NSLocalizedString(@"ConfigureLayout", @""), [item title]]];
			}
		}
	}
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{		
	int i = [(id)menuItem tag];

	switch(i) {
		case menuHints:
			if(workspace == menuSpaceNone)
				return NO;
				
			return ([theHints isVisible] == YES ? NO : YES);

		case menuFAQ:
		case menuIssues:
		case menuSpaceNone:
		case menuSpaceDefault:
		case menuGetMore:
		case menuSettings:
		case menuAbout:
		case menuPreferences:
		case menuGuide:
			return YES;
			
		case menuCheck:
			return NO;

		case menuSaveAs:
			//if(workspace == menuSpaceNone)
			//	return NO;
			
			return YES;	

		case menuDelete:
			if(workspace == menuSpaceNone || workspace == menuSpaceDefault)
				return NO;
			
			return YES;	
			
		case menuCloseHidden:
			return [self canCloseHidden];
			
		case menuBringToFront:
			return [self canBringToFront];

		case menuPutBack:
			return [self canPutAway];
		
		case menuToggle:
			return YES;
					
		case menuIgnore:
			return NO;
	}
	
	if(i <= menuSpaceBase)
		return YES;
	
	if(workspace == menuSpaceNone)
		return NO;
	
	CWidgetList* list = CWidgetList::GetInstance();
	if(list) {
		CWidget* widget = list->GetBySerial(i);

		if(widget && widget->IsValid())
			return YES;
	}
				
	return NO;
}

- (IBAction)menuItemAction: (id)sender
{
	NSMenuItem* menuItem = (NSMenuItem*) sender;
	int i = [menuItem tag];
	
	if(i <= menuSpaceNone)
		[self switchWorkspace: i];
	else if(i >= 100)
		[self selectWidget: i];
}

- (IBAction)checkAction: (id)sender
{
}

// Actions

- (IBAction)buyAction: (id)sender
{
}

- (IBAction)registerAction: (id)sender
{
}

- (IBAction)openPrefsAction: (id)sender
{
	//[thePreferences orderFront: sender];
	[thePreferences display];
	[thePreferences makeKeyAndOrderFront: sender];	

	[NSApp activateIgnoringOtherApps: YES];
}

- (IBAction)openGuideAction: (id)sender
{
	//[theGuide orderFront: sender];
	[theGuide display];
	[theGuide makeKeyAndOrderFront: sender];	

	[NSApp activateIgnoringOtherApps: YES];
}

- (IBAction)openAboutAction: (id)sender
{
	//[NSApp orderFrontStandardAboutPanel: self];

	//[theAbout orderFront: sender];
	[theAbout display];
	[theAbout makeKeyAndOrderFront: sender];	

	[NSApp activateIgnoringOtherApps: YES];
}

- (IBAction)openHintAction: (id)sender
{
	[self writeWorkspace];

	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	
	if(item) {
		item = [wm itemWithTag: workspace];
		
		if(item) 
			[theHints setTitle: [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"ConfigureLayout", @""), [item title]]];
	}

	[self startModalAndIgnore:nil];
	[NSApp activateIgnoringOtherApps: YES];
	[NSApp runModalForWindow: theHints];
	[self finishModalAndIgnore:nil];
	
	[theHints orderOut: self];
	
	[self writeWorkspace];
}

- (IBAction)cancelHintAction: (id)sender
{
	[NSApp stopModal];
}

- (IBAction)closeHintAction: (id)sender
{
	[NSApp stopModal];
	
	[self closeBlotters: YES];
	[self openBlotters];
}

- (IBAction)openSettingsAction: (id)sender
{
	NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"ConfigureTitle", @"")
		defaultButton: NSLocalizedString(@"ConfigureOK", @"")
		alternateButton:nil
		otherButton:nil
		informativeTextWithFormat: NSLocalizedString(@"ConfigureMessage", @"")];

	[[alert window] setTitle: NSLocalizedString(@"ConfigureHelp", @"")];

	[NSApp activateIgnoringOtherApps: YES];
	[[alert window] setLevel: NSStatusWindowLevel+1];
	
	[self startModalAndIgnore:nil];
	[alert runModal];
	[self finishModalAndIgnore:nil];
}

- (IBAction)openFolderAction: (id)sender
{
	NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
	[amnestyWidgetString appendString: NSHomeDirectory()];
	[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];

	NSURL* target = [NSURL fileURLWithPath: amnestyWidgetString];
	if(target)
		LSOpenCFURLRef((CFURLRef) target, NULL);
}

- (IBAction)openFAQs: (id)sender
{
}

- (IBAction)openIssues: (id)sender
{
}

- (IBAction)refreshList: (id)sender
{
	[self writeWorkspace];
	
	CWidgetList* list = CWidgetList::GetInstance();
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			if(widget->IsValid())
				FindPlugins(widget->GetPath(), false);

			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller) {
				[controller willHide];
				[controller close];
			}
			
			NSMenuItem* item = [theMenu itemWithTag: widget->GetSerial()];
			if(item)
				[theMenu removeItem: item];
		}
	}
	
	delete list;
	
	{
		NSMenuItem* item = [theMenu itemWithTag: menuGroup];
		while(item) {
			NSMenu* submenu = [item submenu];
			if(submenu)
				[submenu release];
				
			[theMenu removeItem: item];
			item = [theMenu itemWithTag: menuGroup];
		}
	}

	[self buildList];
	
	[self openWorkspace];
}

- (void)buildList
{
	if([prefAmnestyWidgets state] == NSOnState) {
		NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
		[amnestyWidgetString appendString: NSHomeDirectory()];
		[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];
		FindWidgets((CFStringRef) amnestyWidgetString, 2);

		[self buildGroups];
	}
	
	if(macVersion >= 0x1040 && [prefLocalWidgets state] == NSOnState) {
		NSMutableString* localWidgetString = [NSMutableString stringWithCapacity: 1024];
		[localWidgetString appendString: NSHomeDirectory()];
		[localWidgetString appendString: @"/Library/Widgets"];
		FindWidgets((CFStringRef) localWidgetString, 1);
	}

	if(macVersion >= 0x1040 && [prefSystemWidgets state] == NSOnState) {
		NSMutableString* systemWidgetString = [NSMutableString stringWithCapacity: 1024];
		[systemWidgetString appendString: NSOpenStepRootDirectory()];
		[systemWidgetString appendString: @"Library/Widgets"];
		FindWidgets((CFStringRef) systemWidgetString, 1);
	}
		
	CWidgetList* list = CWidgetList::GetInstance();	
	list->Sort();
	
	{
		NSZone* mZone = [NSMenu menuZone];
		
		if(list->Size() == 0) {
			NSMenuItem*  menuItem = nil;

			menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"ErrorNoWidgets", @"")
				action: @selector(menuItemAction:)
				keyEquivalent: @""];
				
			[menuItem setTag: 1];
			[menuItem setTarget: self];
			[menuItem setEnabled: NO];	
			[theMenu insertItem:menuItem atIndex: (int) 0];
			[menuItem release];
		}
		
		long index = 1;
		
		for(unsigned long i = 1; i <= list->Size(); i++) {
			CWidget* widget = list->GetByIndex(i);
			if(widget) {
				widget->Core();
				
				if(expired && i > 1) {
					widget->Invalidate();
				}

				if(widget->IsValid())
					FindPlugins(widget->GetPath(), true);
			
				NSMenuItem*  menuItem = nil;

				NSString* name = (NSString*) widget->GetName();
				menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: name
					action: @selector(menuItemAction:)
					keyEquivalent: @""];
				
				NSURL* url = (NSURL*) widget->GetIconURL();
				NSImage* icon = nil;
				
				if(url) {
					icon = [[[NSImage alloc] initWithContentsOfURL: url] autorelease];
					[url release];
				}
				
				if(icon == nil) {
					NSURL* imageURL = (NSURL*) widget->GetImageURL();
					if(imageURL) {
						icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
						[imageURL release];
					}
				}
				
				if(icon == nil)
					icon = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NoImage" ofType:@"png"]] autorelease];

				if(icon) {
					NSSize iconSize;
					iconSize.width = 16;
					iconSize.height = 16;
				
					[icon setDataRetained: YES];
					[icon setScalesWhenResized: YES];
					[icon setSize: iconSize];
					[menuItem setImage: icon];
				}
					
				[menuItem setTag: widget->GetSerial()];
				[menuItem setTarget: self];
				[menuItem setEnabled: YES];	
				
				BOOL foundGroup = NO;

				if(theGroups) {
					NSString* path = (NSString*) widget->GetPath();
					if(path) {
						NSArray* pathComponents = [path pathComponents];
						if(pathComponents) {
							unsigned count = [pathComponents count];
							if(count > 2) {
								NSString* folder = [pathComponents objectAtIndex: count - 2];
								if(folder && [folder isEqualToString: @"Widgets"] == NO) {

									NSEnumerator* enumerator = [theGroups objectEnumerator];
									NSString* anObject;
									
									while(foundGroup == NO && (anObject = (NSString*) [enumerator nextObject])) {
										if([anObject isEqualToString: folder]) {
											int top = [theMenu indexOfItemWithTag: menuGroup];
											int bottom = top + [theGroups count];
											
											for(long j = top; j <= bottom; j++) {
												NSMenuItem* fi = [theMenu itemAtIndex: j];
												if(fi) {
													NSMenu* submenu = [fi submenu];
													if(submenu && [[submenu title] isEqualToString: folder]) {
														[submenu addItem: menuItem];
														foundGroup = YES;
													}
												}
											}
										}	
									}
								}
							}
						}
					}
				}
				
				if(foundGroup == NO)
					[theMenu insertItem: menuItem atIndex: (int) ++index];
				
				[menuItem release];
			}
		}
	}	
}

- (void)buildGroups
{
	if(theGroups) {
		[theGroups release];
		theGroups = nil;
	}
		
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			widget->Core();
							
			if(widget->IsValid()) {
				NSString* path = (NSString*) widget->GetPath();
				if(path) {
					NSArray* pathComponents = [path pathComponents];
					if(pathComponents) {
						unsigned count = [pathComponents count];
						if(count > 2) {
							NSString* folder = [pathComponents objectAtIndex: count - 2];
							if(folder && [folder isEqualToString: @"Widgets"] == NO) {
								if(theGroups == nil)
									theGroups = [NSMutableArray arrayWithCapacity: 0];
								
								if(theGroups) {
									BOOL doAdd = YES;
									
									NSEnumerator* enumerator = [theGroups objectEnumerator];
									NSString* anObject;
									
									while(doAdd && (anObject = (NSString*) [enumerator nextObject])) {
										if([anObject isEqualToString: folder])
											doAdd = NO;
									}
									
									if(doAdd) {
										[theGroups addObject: folder];
									}
								}
							}	
						}
					}	
				}
			}
		}
	}
	
	if(theGroups) {
		[theGroups retain];
		
		[theGroups sortUsingSelector:@selector(compare:)];

		NSEnumerator* enumerator = [theGroups objectEnumerator];
		NSString* anObject;
		
		int index = 1;
		NSZone* mZone = [NSMenu menuZone];
		
		while((anObject = (NSString*) [enumerator nextObject])) {			
			NSMenuItem*  menuItem = nil;

			menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: anObject
				action: @selector(menuItemAction:)
				keyEquivalent: @""];
				
			[menuItem setTag: menuGroup];
			[menuItem setTarget: self];
			[menuItem setEnabled: YES];	

			NSZone* mZone = [NSMenu menuZone];
			NSMenu* submenu = [[NSMenu allocWithZone:mZone] initWithTitle: anObject];
			[submenu setDelegate: self];
			[menuItem setSubmenu: submenu];
			
			[theMenu insertItem:menuItem atIndex: (int) ++index];
			[menuItem release];
		}
	}
}

- (IBAction)toggleWorkspace:(id)sender
{
	if(workspace == menuSpaceNone) {
		if(savedWorkspace != menuSpaceNone)
			[self switchWorkspace: savedWorkspace];
		else
			[self switchWorkspace: menuSpaceDefault];
	}
	else {
		int tempWorkspace = workspace;
		[self switchWorkspace: menuSpaceNone];
		savedWorkspace = tempWorkspace;
	}
}

- (void)keyWorkspace:(int)index
{
	if(workspace == index)
		[self switchWorkspace: menuSpaceNone];
	else
		[self switchWorkspace: index];
}

- (void)dropDownMenu
{
	if(statusItem) {
		[statusItem popUpStatusItemMenu: [statusItem menu]];
	}
}

/*- (void)dropDownLayout
{
	if(statusItem) {
		NSMenuItem* item = [theMenu itemAtIndex: 0];
		NSMenu* wm = [item submenu];
		[statusItem popUpStatusItemMenu: wm];
	}
}*/

- (void)openBlotters
{
	if(workspace == menuSpaceNone)
		return;
		
	if([prefSpaceBackground state] == NSOffState)
		return;

	if(theBlotters) {
		if(blotterWorkspace == workspace) {
			NSEnumerator* enumerator = [theBlotters objectEnumerator];
			NSWindow* anObject;
			
			while((anObject = (NSWindow*) [enumerator nextObject])) {
				[anObject orderFront: self];
			}

			return;
		}
		
		[self closeBlotters: YES];
	}	
		
	NSArray* screens = [NSScreen screens];
	if(screens) {
		theBlotters = [NSMutableArray arrayWithCapacity: [screens count]];

		NSEnumerator* enumerator = [screens objectEnumerator];
		NSScreen* anObject;
		
		while((anObject = (NSScreen*) [enumerator nextObject])) {
			NSWindow* window = [[NSWindow alloc]
				initWithContentRect: [anObject frame]
				styleMask: NSBorderlessWindowMask
				backing: NSBackingStoreBuffered
				defer: NO
			];
			
			
			float opacity = [prefSpaceBackOpacity floatValue];
			
			[window setBackgroundColor: [prefSpaceBackColor color]];
			[window setLevel: NSFloatingWindowLevel+1]; 
			[window setAlphaValue: opacity];
			[window setOpaque: NO];
			[window setHasShadow: NO];
			
			if(opacity < .95)
				[window setIgnoresMouseEvents: YES];
			else
				[window setIgnoresMouseEvents: NO];
				
			NSImage* image = [prefSpaceImage image];
			if(image) {
				NSImageView* imageView =  [[NSImageView alloc] init];
				[imageView setImage: [image copy]];
				NSRect imageFrame = [anObject frame];
				imageFrame.origin.x = 0;
				imageFrame.origin.y = 0;
				[imageView setFrame: imageFrame];
				[imageView setImageScaling: NSScaleToFit];
				
				[[window contentView] addSubview: imageView]; 
			}
			
			[window orderFront: self];
			
			[theBlotters addObject: window];
		}
		
		[theBlotters retain];
		
		blotterWorkspace = workspace;
	}
}

- (void)closeBlotters:(BOOL)force
{
	if(theBlotters) {
		NSEnumerator* enumerator = [theBlotters objectEnumerator];
		NSWindow* anObject;
		
		while((anObject = (NSWindow*) [enumerator nextObject])) {
			if(force)
				[anObject close];
			else
				[anObject orderOut: self];
		}
	
		if(force) {
			[theBlotters release];
			theBlotters = nil;
		
			blotterWorkspace = menuSpaceNone;
		}
	}
}

- (void)buildWorkspaces:(BOOL)bind
{
	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	
	int tag = menuSpaceBase;
	item = [wm itemWithTag: tag];
	while(item) {
		[wm removeItem: item];
		
		tag--;
		item = [wm itemWithTag: tag];
	}

	item = [wm itemWithTag: menuIgnore];
	if(item)
		[wm removeItem: item];
	
	theWorkspaces = [NSMutableArray arrayWithCapacity: 0];
	NSMutableString* workspaceString = [NSMutableString stringWithCapacity: 1024];
	[workspaceString appendString: NSHomeDirectory()];
	[workspaceString appendString: @"/Library/Preferences"];
	FindWorkspaces((CFStringRef) workspaceString, theWorkspaces);

	NSEnumerator* enumerator = [theWorkspaces objectEnumerator];
	NSString* anObject;
			
	NSZone* mZone = [NSMenu menuZone];
	BOOL didBuild = NO;
		
	int index = 0;
	while((anObject = (NSString*) [enumerator nextObject])) {
		NSMenuItem*  menuItem = nil;
		
		NSArray* objectComponents = [anObject componentsSeparatedByString: @"."];
		int count = [objectComponents count];
		if(count > 2) {
			NSString* objectTitle = (NSString*) [objectComponents objectAtIndex: count - 2];
			
			if(objectTitle) {
				if(didBuild == NO) {
					menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"UserLayouts", @"")
						action: @selector(menuItemAction:)
						keyEquivalent: @""];

					[menuItem setTag: menuIgnore];
					[menuItem setTarget: self];
					[menuItem setEnabled: NO];	
					[wm insertItem:menuItem atIndex: (int) 2];
					didBuild = YES;
				}
				
				menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: objectTitle
					action: @selector(menuItemAction:)
					keyEquivalent: @""];
					
				[menuItem setTag: menuSpaceBase - index];
				[menuItem setTarget: self];
				[menuItem setEnabled: NO];	
				[wm insertItem:menuItem atIndex: (int) 3 + index];
				[menuItem release];
				
				index++;
			}
		}
	}

	if(theWorkspaces) {
		NSEnumerator* enumerator = [theWorkspaces objectEnumerator];
		NSString* anObject;
		
		long index = 0;
		while((anObject = (NSString*) [enumerator nextObject])) {
			[self buildWorkspaceHotKeys: menuSpaceBase - index andBind: bind];
			index++;
		}
	}
}

- (void)switchWorkspace:(int)index
{
	if(workspace == index)
		return;
		
	if(workspace != menuSpaceNone)
		[self writeWorkspace];
			
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				[controller writePreferences];
		}
	}
	
	workspace = index;	
	if(workspace != menuSpaceNone)
		savedWorkspace = index;
	
	[self closeWorkspace];

	didSwitchWorkspace = YES;
	
	[NSApp activateIgnoringOtherApps: YES];
					
	if(index != menuSpaceNone)
		[self openWorkspace];

	didSwitchWorkspace = NO;
}

- (void)closeWorkspace
{
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller) {
				if([[controller window] isVisible]) {
					[controller willHide];
					[[controller window] orderOut: self];
					
					if([self useAutoClose])
						[controller close];
				}
				else {
					if([controller busy])
						[controller close];
				}
			}
		}
	}
	
	[self closeBlotters: NO];
}

- (void)openWorkspace
{
	NSString* com = nil; 

	if(workspace == menuSpaceNone)
		return;
		
	if(workspace == menuSpaceDefault) {
		int version = 0;
		{
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"PrefVersion", (CFStringRef) @"com.mesadynamics.Amnesty");
			if(setting)
				version = [setting intValue];
		}
		
		if(version && version < 80)
			com = @"com.mesadynamics.Amnesty";
		else
			com = @"com.mesadynamics.AmnestyWidgets";
	}
	else {
		NSMenuItem* item = [theMenu itemAtIndex: 0];
		NSMenu* wm = [item submenu];
		
		item = [wm itemWithTag: workspace];

		if(item)
			com = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@", [item title]];
	}

	if(com) {
		{
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"BackgroundEnable", (CFStringRef) com);
			if(setting)
				[prefSpaceBackground setState: [setting intValue]];
		}

		{
			NSString* setting = (NSString*) CFPreferencesCopyAppValue((CFStringRef) @"BackgroundImage", (CFStringRef) com);
			if(setting) {
				FileImageView* fim = (FileImageView*) prefSpaceImage;
				NSImage* image = nil;
				
				NSFileManager* fm = [NSFileManager defaultManager];
				if([fm fileExistsAtPath: setting])
					image = [[NSImage alloc] initWithContentsOfFile: setting];
					
				if(image) {
					[prefSpaceImage setImage: image];
					[fim setFile: setting];
				}
				else
					[prefSpaceImage setImage:nil];
			}
			else
				[prefSpaceImage setImage:nil];
		}

		{
			float red = 0.0;
			float green = 0.0;
			float blue = 0.0;

			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"BackgroundRed", (CFStringRef) com);
			if(setting)
				red = [setting floatValue];

			setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"BackgroundGreen", (CFStringRef) com);
			if(setting)
				green = [setting floatValue];

			setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"BackgroundBlue", (CFStringRef) com);
			if(setting)
				blue = [setting floatValue];

			NSColor* color = [NSColor colorWithCalibratedRed: red green: green blue: blue alpha: 1.0];
			[prefSpaceBackColor setColor: color];
		}

		{
			NSNumber* opacity = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef)  @"BackgroundOpacity", (CFStringRef) com);
			if(opacity)
				[prefSpaceBackOpacity setFloatValue: [opacity floatValue]];
		}

		[self openBlotters];
		
		if([prefSaveStates state] == NSOnState) {
			CWidgetList* list = CWidgetList::GetInstance();

			for(unsigned long i = 1; i <= list->Size(); i++) {
				CWidget* widget = list->GetByIndex(i);
				if(widget && widget->IsValid()) {
					NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
					[key appendString: (NSString*) widget->GetID()];
					[key appendString: @"-WidgetOpen"];

					NSNumber* b = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
					if(b && [b boolValue] == YES) {
						[self selectWidget: widget->GetSerial()];
					}
				}
			}
		}

		{
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SpaceLock", (CFStringRef) com);
			if(setting)
				[prefSpaceLock setState: [setting intValue]];
		}

		NSMenuItem* item = [theMenu itemAtIndex: 0];
		NSMenu* wm = [item submenu];
		item = [wm itemWithTag: workspace];

		if(item) {
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SpaceKey", (CFStringRef) com);
			if(setting) {
				int value = [setting intValue];
				[prefSpaceKey selectItemAtIndex: value];
			}
			else
				[prefSpaceKey selectItemAtIndex: 0];

			setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SpaceModifiers", (CFStringRef) com);
			if(setting) {
				UInt32 modifiers = [setting intValue];
				[prefSpaceCommand setState: ((modifiers & cmdKey) ? NSOnState : NSOffState)];
				[prefSpaceControl setState: ((modifiers & controlKey) ? NSOnState : NSOffState)];
				[prefSpaceOption setState: ((modifiers & optionKey) ? NSOnState : NSOffState)];
				[prefSpaceShift setState: ((modifiers & shiftKey) ? NSOnState : NSOffState)];
			}
			else {
				[prefSpaceCommand setState: NSOffState];
				[prefSpaceControl setState: NSOffState];
				[prefSpaceOption setState: NSOffState];
				[prefSpaceShift setState: NSOffState];
			}
		}
	}
}

- (void)readWorkspace
{
	NSString* workspaceName = (NSString*) CFPreferencesCopyAppValue((CFStringRef) @"CurrentLayout", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(workspaceName) {
		if([workspaceName isEqualToString: @"com.mesadynamics.AmnestyWidgets.plist"])
			workspace = menuSpaceDefault;
		else if([workspaceName isEqualToString: @"NULL"])
			workspace = menuSpaceNone;
		else if(theWorkspaces) {
			BOOL didFindWorkspace = NO;
			
			NSEnumerator* enumerator = [theWorkspaces objectEnumerator];
			NSString* anObject;
					
			long index = 0;		
			while((anObject = (NSString*) [enumerator nextObject])) {
				if([workspaceName isEqualToString:anObject]) {
					workspace = menuSpaceBase - index;
					didFindWorkspace = YES;
					break;
				}
				
				index++;
			}
			
			if(didFindWorkspace == NO)
				workspace = menuSpaceDefault;
		}
	}
	
	savedWorkspace = workspace;
}

- (void)writeWorkspace
{
	NSString* com = [self workspaceName]; 
	if(com)
		[self writeWorkspace: com];
}

- (void)writeWorkspace:(NSString*)com
{	
	if(doSkipWrite) {
		doSkipWrite = NO;
		return;
	}

	if(com) {
		CWidgetList* list = CWidgetList::GetInstance();

		if([prefSpaceLock state] == NSOffState) {
			for(unsigned long i = 1; i <= list->Size(); i++) {
				CWidget* widget = list->GetByIndex(i);
				if(widget) {
					BOOL isVisible = NO;
					
					if(widget->IsValid()) {
						WidgetController* controller = (WidgetController*) widget->GetController();
						if(controller) {
							if([[controller window] isVisible])
								isVisible = YES;
						}
					
						NSNumber* b = [NSNumber numberWithBool: isVisible];
						NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
						[key appendString: (NSString*) widget->GetID()];
						[key appendString: @"-WidgetOpen"];

						CFPreferencesSetAppValue((CFStringRef) key, b, (CFStringRef) com);	
					}
				}
			}
		}
		
		NSNumber* y;

		y = [NSNumber numberWithBool: [prefSpaceBackground state]];
		CFPreferencesSetAppValue((CFStringRef) @"BackgroundEnable", y, (CFStringRef) com);	

		FileImageView* fim = (FileImageView*) prefSpaceImage;
		NSString* file = [fim getFile];
		if(file && [fim image])
			CFPreferencesSetAppValue((CFStringRef) @"BackgroundImage", file, (CFStringRef) com);	
		else
			CFPreferencesSetAppValue((CFStringRef) @"BackgroundImage", NULL, (CFStringRef) com);	
		
		{
			NSColor* color = [prefSpaceBackColor color];
			
			y = [NSNumber numberWithFloat: [color redComponent]];
			CFPreferencesSetAppValue((CFStringRef) @"BackgroundRed", y, (CFStringRef) com);	

			y = [NSNumber numberWithFloat: [color greenComponent]];
			CFPreferencesSetAppValue((CFStringRef) @"BackgroundGreen", y, (CFStringRef) com);	

			y = [NSNumber numberWithFloat: [color blueComponent]];
			CFPreferencesSetAppValue((CFStringRef) @"BackgroundBlue", y, (CFStringRef) com);	
		}
		
		y = [NSNumber numberWithFloat: [prefSpaceBackOpacity floatValue]];
		CFPreferencesSetAppValue((CFStringRef) @"BackgroundOpacity", y, (CFStringRef) com);	

		y = [NSNumber numberWithBool: [prefSpaceLock state]];
		CFPreferencesSetAppValue((CFStringRef) @"SpaceLock", y, (CFStringRef) com);	

		CFPreferencesSetAppValue((CFStringRef) @"SpaceKey", [NSNumber numberWithInt: [prefSpaceKey indexOfSelectedItem]], (CFStringRef) com);	
		UInt32 spaceModifiers = 0;
		if([prefSpaceCommand state] == NSOnState)
			spaceModifiers |= cmdKey;
		if([prefSpaceControl state] == NSOnState)
			spaceModifiers |= controlKey;
		if([prefSpaceOption state] == NSOnState)
			spaceModifiers |= optionKey;
		if([prefSpaceShift state] == NSOnState)
			spaceModifiers |= shiftKey;
		CFPreferencesSetAppValue((CFStringRef) @"SpaceModifiers", [NSNumber numberWithInt: spaceModifiers], (CFStringRef) com);	

		CFPreferencesAppSynchronize((CFStringRef) com);
	}
}

- (void)buildWorkspaceHotKeys: (int)usingWorkspace andBind:(BOOL)bind
{
	NSString* com = nil; 

	if(usingWorkspace == menuSpaceNone)
		return;
		
	if(usingWorkspace == menuSpaceDefault) {
		int version = 0;
		{
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"PrefVersion", (CFStringRef) @"com.mesadynamics.Amnesty");
			if(setting)
				version = [setting intValue];
		}
		
		if(version && version < 80)
			com = @"com.mesadynamics.Amnesty";
		else
			com = @"com.mesadynamics.AmnestyWidgets";
	}
	else {
		NSMenuItem* item = [theMenu itemAtIndex: 0];
		NSMenu* wm = [item submenu];
		
		item = [wm itemWithTag: usingWorkspace];

		if(item)
			com = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@", [item title]];
	}

	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	item = [wm itemWithTag: usingWorkspace];

	if(item) {
		BOOL hasSpace = NO;
		int value = 0;
		UInt32 modifiers = 0;
		
		NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SpaceKey", (CFStringRef) com);
		if(setting) {
			value = [setting intValue];
			
			if(value) {
				unichar ch[4];
				switch(value) {
					case 1:		ch[0] = NSF1FunctionKey;	break;
					case 2:		ch[0] = NSF2FunctionKey;	break;
					case 3:		ch[0] = NSF3FunctionKey;	break;
					case 4:		ch[0] = NSF4FunctionKey;	break;
					case 5:		ch[0] = NSF5FunctionKey;	break;
					case 6:		ch[0] = NSF6FunctionKey;	break;
					case 7:		ch[0] = NSF7FunctionKey;	break;
					case 8:		ch[0] = NSF8FunctionKey;	break;
					case 9:		ch[0] = NSF9FunctionKey;	break;
					case 10:	ch[0] = NSF10FunctionKey;	break;
					case 11:	ch[0] = NSF11FunctionKey;	break;
					case 12:	ch[0] = NSF12FunctionKey;	break;
					case 13:	ch[0] = NSF13FunctionKey;	break;
					case 14:	ch[0] = NSF14FunctionKey;	break;
					case 15:	ch[0] = NSF15FunctionKey;	break;
					
					default:
						value = 0;
				}
				
				if(value) {
					[item setKeyEquivalent: [NSString stringWithCharacters:ch length:1]];
					[item setKeyEquivalentModifierMask: NSFunctionKeyMask];
					
					hasSpace = YES;
				}
			}
		}

		setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SpaceModifiers", (CFStringRef) com);
		if(setting) {
			modifiers = [setting intValue];
			
			if(hasSpace) {
				unsigned int spaceModifiers = NSFunctionKeyMask;
			
				if((modifiers & cmdKey))
					spaceModifiers += NSCommandKeyMask;
				if((modifiers & controlKey))
					spaceModifiers += NSControlKeyMask;
				if((modifiers & optionKey))
					spaceModifiers += NSAlternateKeyMask;
				if((modifiers & shiftKey))
					spaceModifiers += NSShiftKeyMask;

				[item setKeyEquivalentModifierMask: spaceModifiers];
			}
		}
		
		if(hasSpace && bind)
			UHotKeys::AddKey(usingWorkspace, value, modifiers);
	}
}

- (NSString*)workspaceName
{
	if(workspace == menuSpaceNone)
		return nil;
		
	if(workspace == menuSpaceDefault)
		return @"com.mesadynamics.AmnestyWidgets";
	
	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	
	item = [wm itemWithTag: workspace];

	if(item)
		return [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@", [item title]];
	
	return nil;
}

- (BOOL)useAutoClose
{
	return ([prefCloseOnHide state] == NSOnState ? YES : NO);
}

- (BOOL)canCloseHidden
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller && [[controller window] isVisible] == NO) {
				return YES;
			}
		}
	}
	
	return NO;
}

- (BOOL)canBringToFront
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				if([controller canBringToFront] == YES)
					return YES;
		}
	}
	
	return NO;
}

- (BOOL)canPutAway
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				if([controller canPutAway] == YES)
					return YES;
		}
	}
	
	return NO;
}

- (BOOL)doesEnableFlip
{
	return enableFlip;
}

- (BOOL)doesEnableDrop
{
	return enableDrop;
}

- (IBAction)bringToFrontAction: (id)sender
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				[controller bringToFront];
		}
	}
}

- (IBAction)putAwayAction: (id)sender
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				[controller putAway];
		}
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSString* saveAsName = [theWorkspaceNameField stringValue];
	if([saveAsName length] == 0) {
		if([theWorkspaceNameButton isEnabled] == YES)
			[theWorkspaceNameButton setEnabled: NO];
	}
	else {
		if([theWorkspaceNameButton isEnabled] == NO)
			[theWorkspaceNameButton setEnabled: YES];
	} 
}

- (IBAction)saveAsAction: (id)sender
{
	[theWorkspaceNameField setStringValue: @""];
	
	[self startModalAndIgnore:nil];
	[NSApp activateIgnoringOtherApps: YES];	
	[NSApp runModalForWindow: theWorkspaceName];
	[self finishModalAndIgnore:nil];
		
	[theWorkspaceName orderOut: self];
}

- (IBAction)saveAsDoneAction: (id)sender
{
	[NSApp stopModal];
	
	NSString* saveAsName = [theWorkspaceNameField stringValue];
	NSRange range1 = [saveAsName rangeOfString: @"."];
	NSRange range2 = [saveAsName rangeOfString: @"/"];
	NSRange range3 = [saveAsName rangeOfString: @":"];
	if(
		range1.location != NSNotFound ||
		range2.location != NSNotFound ||
		range3.location != NSNotFound
	)
		return;
		
	if([saveAsName length] == 0 )
		return;
	
	[self writeWorkspace];	
	
	[prefSpaceKey selectItemAtIndex: 0]; // don't copy the hot key!
	
	NSString* com = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@", saveAsName];
	[self writeWorkspace: com];
	[self buildWorkspaces: NO];

	NSString* name = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@.plist", saveAsName];
	
	CFPreferencesSetAppValue((CFStringRef) @"CurrentLayout", (CFStringRef) name, (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesAppSynchronize((CFStringRef) @"com.mesadynamics.Amnesty");

	NSEnumerator* enumerator = [theWorkspaces objectEnumerator];
	NSString* anObject;
	
	long index = 0;
	while((anObject = (NSString*) [enumerator nextObject])) {
		if([name isEqualToString: anObject]) {
			workspace = menuSpaceBase - index;
			savedWorkspace = workspace;

			CWidgetList* list = CWidgetList::GetInstance();

			for(unsigned long i = 1; i <= list->Size(); i++) {
				CWidget* widget = list->GetByIndex(i);
				if(widget) {
					WidgetController* controller = (WidgetController*) widget->GetController();
					if(controller)
						[controller writePreferences];
				}
			}
			
			break;
		}
	}

	[self readWorkspace];
}

- (IBAction)saveAsCancelAction: (id)sender
{
	[NSApp stopModal];
}

- (IBAction)deleteAction: (id)sender
{
	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	
	item = [wm itemWithTag: workspace];
	if(item == nil)
		return;
		
	NSString* message = [NSString stringWithFormat: NSLocalizedString(@"DeleteMessage", @""), [item title]];
	
	NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"DeleteTitle", @"")
		defaultButton: NSLocalizedString(@"DeleteConfirm", @"")
		alternateButton: NSLocalizedString(@"DeleteCancel", @"")
		otherButton:nil
		informativeTextWithFormat:@"%@", message];
				
	[NSApp activateIgnoringOtherApps: YES];
	[[alert window] setLevel: NSStatusWindowLevel+1];

	BOOL doDelete = NO;

	[self startModalAndIgnore:nil];
	if([alert runModal] == 1)
		doDelete = YES;
	[self finishModalAndIgnore:nil];
	
	if(doDelete) {
		[self closeWorkspace];

		NSString* name = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@.plist", [item title]];

		NSMutableString* layoutPath = [NSMutableString stringWithCapacity: 1024];
		[layoutPath appendString: NSHomeDirectory()];
		[layoutPath appendString: @"/Library/Preferences/"];
		[layoutPath appendString: name];

		NSFileManager* fm = [NSFileManager defaultManager];
		if([fm fileExistsAtPath: layoutPath])
			[fm removeFileAtPath: (NSString*) layoutPath handler:nil];

		[self buildWorkspaces: NO];
		
		workspace = menuSpaceNone;
		savedWorkspace = menuSpaceNone;
	}
}

- (IBAction)closeHiddenAction: (id)sender
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller && [[controller window] isVisible] == NO) {
				[controller close];
			}
		}
	}
}

- (IBAction)setPrefsAction: (id)sender
{
	if([prefReduceCPU state] == NSOnState) 
		setpriority(PRIO_PROCESS, 0, 20);
	else
		setpriority(PRIO_PROCESS, 0, 0);
}

- (IBAction)getMoreAction: (id)sender
{
	NSURL* target = [NSURL URLWithString: @"http://www.apple.com/downloads/dashboard/"];
	if(target)
		LSOpenCFURLRef((CFURLRef) target, NULL);
}

- (void)selectWidget:(int)index
{
	UInt32 modifiers = GetCurrentKeyModifiers();

	CWidgetList* list = CWidgetList::GetInstance();
	CWidget* widget = list->GetBySerial(index);
	if(widget) {
		if(widget->IsValid() == false)
			return;
			
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller) { // it's already open
			if([[controller window] isVisible]) {
				if((modifiers & (1<<11))) {
					[[controller window] makeKeyAndOrderFront: self];	
					[controller showSettings:self];
				}
				else if((modifiers & (1<<12))) {
					[[controller window] makeKeyAndOrderFront: self];	
					[controller forceMenu:self];
				}	
				else if((modifiers & (1<<9)))
					[[controller window] center];
				else {
					[controller willHide];
					[[controller window] orderOut: controller];
					
					if([self useAutoClose])
						[controller close];
				}
			}
			else {
				if([controller busy])
					[controller close];
				else if(didSwitchWorkspace == YES) {
					[NSApp activateIgnoringOtherApps: YES];

					[controller restore];
				}
				else {
					[NSApp activateIgnoringOtherApps: YES];
					
					[controller updateDisplay];
					[controller willShow];
				}
				
				//if(workspace == menuSpaceNone)
				//	workspace = menuSpaceDefault;
			}
				
			return;
		}
		
		[self performSelectorOnMainThread: @selector(openWidget:) withObject: [NSNumber numberWithInt:index] waitUntilDone:NO];
	}
}

- (void)openWidget:(id)sender
{
	NSNumber* n = sender;
	CWidgetList* list = CWidgetList::GetInstance();
	CWidget* widget = list->GetBySerial([n intValue]);

	if(widget == nil)
		return;
				
	widget->LoadFonts();
	
	WidgetController* controller = [[WidgetController alloc] init];

	if([prefSavePositions state] == NSOnState)
		[controller setDoPosition: YES];
	else
		[controller setDoPosition: NO];

	if([prefSaveSettings state] == NSOnState)
		[controller setDoSettings: YES];
	else
		[controller setDoSettings: NO];
		
	[controller setCompatible: (widget->GetCompatible() ? YES : NO)];
	
	[controller setSecurityFile: (widget->GetSecurityFile() ? YES : NO)];
	[controller setSecurityPlugins: (widget->GetSecurityPlugins() ? YES : NO)];
	[controller setSecurityJava: (widget->GetSecurityJava() ? YES : NO)];
	[controller setSecurityNet: (widget->GetSecurityNet() ? YES : NO)];
	[controller setSecuritySystem: (widget->GetSecuritySystem() ? YES : NO)];

	[controller setLocalFolder: widget->GetLocalFolder()];

	NSURL* widgeturl = (NSURL*) widget->GetWidgetURL();
	[controller setWidgetURL: widgeturl];
	
	NSURL* pluginurl = (NSURL*) widget->GetPluginURL();
	if(pluginurl) // optional
		[controller setPluginURL: pluginurl];

	NSURL* imageurl = (NSURL*) widget->GetImageURL();
	if(imageurl) // optional
		[controller setImageURL: imageurl];
										
	NSURL* iconurl = (NSURL*) widget->GetIconURL();
	if(iconurl) // optional
		[controller setIconURL: iconurl];
										
	NSString* bid = (NSString*) widget->GetID();
	[controller setWidgetID: bid];
	
	NSString* path = (NSString*) widget->GetPath();
	[controller setWidgetPath: path];
		
	NSWindow* window = [controller window];
	[window setTitle: (NSString*) widget->GetName()];
				
	NSRect widgetFrame;
	widgetFrame.origin.x = 0.0;
	widgetFrame.origin.y = 0.0;
	widgetFrame.size.width = (float) widget->GetWidth();
	widgetFrame.size.height = (float) widget->GetHeight();
	
	NSRect contentRect = [window contentRectForFrameRect: widgetFrame];
	[window setFrame: contentRect display: NO];
			
	[window center];

	/*NSRect frame = [window frame];
	frame.origin.x += (640.0 - (float) widget->GetWidth()) * .5;
	frame.origin.y -= (480.0 - (float) widget->GetHeight()) * .5;
	[window setFrameOrigin: frame.origin];*/
	
	if([controller verify] == NO) {	
		NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"SecurityTitle", @"")
				defaultButton: NSLocalizedString(@"SecurityGrant", @"")
				alternateButton: NSLocalizedString(@"SecurityDontGrant", @"")
				otherButton:nil
				informativeTextWithFormat:
					NSLocalizedString(@"SecurityMessage", @""),
					(NSString*) widget->GetName(), 
					[controller verifyString]
		];
			
		NSURL* url = (NSURL*) widget->GetIconURL();
		NSImage* icon = nil;
		
		if(url) {
			icon = [[[NSImage alloc] initWithContentsOfURL: url] autorelease];
			[url release];
		}
		
		if(icon == nil) {
			NSURL* imageURL = (NSURL*) widget->GetImageURL();
			if(imageURL) {
				icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
				[imageURL release];
			}
		}
		
		if(icon)
			[alert setIcon: icon];

		[NSApp activateIgnoringOtherApps: YES];
		[[alert window] setLevel: NSStatusWindowLevel+1];

		[self startModalAndIgnore:controller];
		int alertReturn = [alert runModal];
		[self finishModalAndIgnore:controller];
		
		if(alertReturn == 0) {
			[controller close];
			return;
		}

		[controller verifyStamp];
	}

	widget->SetController(controller);

	[controller prepareWidget:self];

	//if(workspace == menuSpaceNone)
	//	workspace = menuSpaceDefault;
}

- (void)handleOpen:(id)sender
{
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			
			if(controller) {
				if([controller closing] == NO && [controller loaded] == NO) {
					[self performSelectorOnMainThread: @selector(handleOpenTask:) withObject: controller waitUntilDone:NO];
					return;
				}	
			}
		}
	}
}

- (void)handleOpenTask:(id)sender
{
	WidgetController* controller = sender;
	
	if([controller closing] == NO && [controller loaded] == NO) {
		if([controller busy] == YES)
			[controller runWidget:self];
		else
			[controller loadWidget:self];
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	opener = [NSTimer
		scheduledTimerWithTimeInterval: (double) 0.125
		target: self
		selector:@selector(handleOpen:)
		userInfo: nil
		repeats: YES];

	[self registerForSleepWakeNotification];
		
	if([prefReduceCPU state] == NSOnState) {
		setpriority(PRIO_PROCESS, 0, 20);
	}
	
	if([prefLaunchHidden state] == NSOnState) {
		// let the savedWorkspace point correctly
		savedWorkspace = workspace;
		workspace = menuSpaceNone;
		
		doSkipOpen = YES;
	}
	
	[self buildList];
	
	NSNumber* setting = nil;
	
	int version = 0;
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"PrefVersion", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		version = [setting intValue];
	
	if(version == 0 && doSkipGuide == NO)
		[self openGuideAction: self];
		
	if(doSkipOpen == NO)
		[self openWorkspace];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)fileName
{
	// todo: ask for "refresh" after a batch; ask for replace; ask for install/test under Tiger?

	if([fileName hasSuffix: @".wdgt"]) {
		if(macVersion < 0x1040) {
			NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
			[amnestyWidgetString appendString: NSHomeDirectory()];
			[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets/"];
			
			if([fileName hasPrefix: amnestyWidgetString] == NO) {
				NSArray* pathComponents = [fileName pathComponents];
				NSString* pathFileName = (NSString*) [pathComponents lastObject];
				[amnestyWidgetString appendString: pathFileName];

				NSFileManager* fm = [NSFileManager defaultManager];
				if([fm fileExistsAtPath: amnestyWidgetString])
					[fm removeFileAtPath: amnestyWidgetString handler:nil];
					
				return [fm movePath: fileName toPath: amnestyWidgetString handler:nil];
 			}
		}
	}
	
	return NO;
}

- (void)applicationWillHide:(NSNotification* )aNotification
{	
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				[controller hideNow];
		}
	}
}

- (void)applicationWillUnhide:(NSNotification* )aNotification
{
	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller)
				[controller showNow];
		}
	}
}

- (void)applicationWillTerminate:(NSNotification* )aNotification
{
	UBusy::SetStatusItem(nil);

	[self deregisterForSleepWakeNotification];

	[self writeWorkspace];
	
	if(workspace == menuSpaceNone && savedWorkspace != menuSpaceNone)
		workspace = savedWorkspace;
	[self writePreferences];

	CWidgetList* list = CWidgetList::GetInstance();
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			if(widget->IsValid())
				FindPlugins(widget->GetPath(), false);
				
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller) {
				[controller willHide];
				[controller fastClose];
			}
		}
	}

	CFontList* fontList = CFontList::GetInstance(false);
	if(fontList)
		fontList->Free();

	// clean up temporary files
	NSString* tempDir = NSTemporaryDirectory();
	if(tempDir) {
		NSFileManager* fm = [NSFileManager defaultManager];
		NSArray* contents = [fm directoryContentsAtPath:tempDir];
		NSEnumerator* enumerator = [contents objectEnumerator];
		NSString* tempFile;
		NSString* prefix = @"Amnesty.";
		
		while(tempFile = [enumerator nextObject]) {
			if([tempFile hasPrefix:prefix]) {
				NSString* tempFilePath = [NSString stringWithFormat:@"%@%@", tempDir, tempFile];
				[fm removeFileAtPath:tempFilePath handler:nil];
			}
		}
	}
}

- (void)buildHotKeys
{
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F1", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F2", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F3", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F4", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F5", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F6", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F7", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F8", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F9", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F10", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F11", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F12", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F13", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F14", @"")];
	[prefDropKey addItemWithTitle:  NSLocalizedString(@"F15", @"")];

	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F1", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F2", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F3", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F4", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F5", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F6", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F7", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F8", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F9", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F10", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F11", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F12", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F13", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F14", @"")];
	[prefToggleKey addItemWithTitle:  NSLocalizedString(@"F15", @"")];

	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F1", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F2", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F3", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F4", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F5", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F6", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F7", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F8", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F9", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F10", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F11", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F12", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F13", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F14", @"")];
	[prefSpaceKey addItemWithTitle:  NSLocalizedString(@"F15", @"")];
}

- (void)readPreferences
{
	NSNumber* setting = nil;
	
	int version = 0;
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"PrefVersion", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		version = [setting intValue];
		
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SaveStates", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefSaveStates setState: [setting intValue]];
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SavePositions", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefSavePositions setState: [setting intValue]];
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SaveSettings", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefSaveSettings setState: [setting intValue]];
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"LocalWidgets", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefLocalWidgets setState: [setting intValue]];
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"SystemWidgets", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefSystemWidgets setState: [setting intValue]];
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"AmnestyWidgets", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefAmnestyWidgets setState: [setting intValue]];

	// .85
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"LaunchHidden", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefLaunchHidden setState: [setting intValue]];

	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"AutoClose", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefCloseOnHide setState: [setting intValue]];

	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"MenuKey", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefDropKey selectItemAtIndex: [setting intValue]];

	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"MenuModifiers", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting) {
		UInt32 modifiers = [setting intValue];
		[prefDropCommand setState: ((modifiers & cmdKey) ? NSOnState : NSOffState)];
		[prefDropControl setState: ((modifiers & controlKey) ? NSOnState : NSOffState)];
		[prefDropOption setState: ((modifiers & optionKey) ? NSOnState : NSOffState)];
		[prefDropShift setState: ((modifiers & shiftKey) ? NSOnState : NSOffState)];
	}

	NSMenuItem* item = [theMenu itemAtIndex: 0];
	NSMenu* wm = [item submenu];
	item = [wm itemWithTag: menuToggle];

	BOOL hasToggle = NO;

	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"ToggleKey", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting) {
		int value = [setting intValue];
		[prefToggleKey selectItemAtIndex: value];
		
		if(value) {
			unichar ch[4];
			switch(value) {
				case 1:		ch[0] = NSF1FunctionKey;	break;
				case 2:		ch[0] = NSF2FunctionKey;	break;
				case 3:		ch[0] = NSF3FunctionKey;	break;
				case 4:		ch[0] = NSF4FunctionKey;	break;
				case 5:		ch[0] = NSF5FunctionKey;	break;
				case 6:		ch[0] = NSF6FunctionKey;	break;
				case 7:		ch[0] = NSF7FunctionKey;	break;
				case 8:		ch[0] = NSF8FunctionKey;	break;
				case 9:		ch[0] = NSF9FunctionKey;	break;
				case 10:	ch[0] = NSF10FunctionKey;	break;
				case 11:	ch[0] = NSF11FunctionKey;	break;
				case 12:	ch[0] = NSF12FunctionKey;	break;
				case 13:	ch[0] = NSF13FunctionKey;	break;
				case 14:	ch[0] = NSF14FunctionKey;	break;
				case 15:	ch[0] = NSF15FunctionKey;	break;
				
				default:
					value = 0;
			}
			
			if(value) {
				[item setKeyEquivalent: [NSString stringWithCharacters:ch length:1]];
				[item setKeyEquivalentModifierMask: NSFunctionKeyMask];
				
				hasToggle = YES;
			}
		}
	}
	
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"ToggleModifiers", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting) {
		UInt32 modifiers = [setting intValue];
		[prefToggleCommand setState: ((modifiers & cmdKey) ? NSOnState : NSOffState)];
		[prefToggleControl setState: ((modifiers & controlKey) ? NSOnState : NSOffState)];
		[prefToggleOption setState: ((modifiers & optionKey) ? NSOnState : NSOffState)];
		[prefToggleShift setState: ((modifiers & shiftKey) ? NSOnState : NSOffState)];
		
		if(hasToggle) {
			unsigned int toggleModifiers = NSFunctionKeyMask;
		
			if([prefToggleCommand state] == NSOnState)
				toggleModifiers += NSCommandKeyMask;
			if([prefToggleControl state] == NSOnState)
				toggleModifiers += NSControlKeyMask;
			if([prefToggleOption state] == NSOnState)
				toggleModifiers += NSAlternateKeyMask;
			if([prefToggleShift state] == NSOnState)
				toggleModifiers += NSShiftKeyMask;

			[item setKeyEquivalentModifierMask: toggleModifiers];
		}
	}

	// 1.0.1
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"ReduceCPU", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		[prefReduceCPU setState: [setting intValue]];

	// 1.2.1
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"EnableFlip", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		enableFlip = [setting boolValue];
		
	setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"EnableDrop", (CFStringRef) @"com.mesadynamics.Amnesty");
	if(setting)
		enableDrop = [setting boolValue];

	if(macVersion < 0x1040) { // override for Panther
		[prefSystemWidgets setState: NSOffState];
		[prefSystemWidgets setEnabled: NO];
		
		[prefLocalWidgets setState: NSOffState];
		[prefLocalWidgets setEnabled: NO];
		
		[prefDropKey selectItemAtIndex: 0];
		[prefDropKey setHidden: YES];
		[prefDropCommand setHidden: YES];
		[prefDropControl setHidden: YES];
		[prefDropOption setHidden: YES];
		[prefDropShift setHidden: YES];
		[prefDropTitle setHidden: YES];
	}	
	 
	[self readWorkspace]; 
}

- (void)writePreferences
{
	CFPreferencesSetAppValue((CFStringRef) @"PrefVersion", [NSNumber numberWithInt: 160], (CFStringRef) @"com.mesadynamics.Amnesty");

	CFPreferencesSetAppValue((CFStringRef) @"SaveStates", [NSNumber numberWithInt: [prefSaveStates state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"SavePositions", [NSNumber numberWithBool: [prefSavePositions state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"SaveSettings", [NSNumber numberWithBool: [prefSaveSettings state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"LocalWidgets", [NSNumber numberWithBool: [prefLocalWidgets state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"SystemWidgets", [NSNumber numberWithBool: [prefSystemWidgets state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"AmnestyWidgets", [NSNumber numberWithBool: [prefAmnestyWidgets state]], (CFStringRef) @"com.mesadynamics.Amnesty");	

	// .85
	CFPreferencesSetAppValue((CFStringRef) @"LaunchHidden", [NSNumber numberWithBool: [prefLaunchHidden state]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	CFPreferencesSetAppValue((CFStringRef) @"AutoClose", [NSNumber numberWithBool: [prefCloseOnHide state]], (CFStringRef) @"com.mesadynamics.Amnesty");	

	CFPreferencesSetAppValue((CFStringRef) @"MenuKey", [NSNumber numberWithInt: [prefDropKey indexOfSelectedItem]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	UInt32 menuModifiers = 0;
	if([prefDropCommand state] == NSOnState)
		menuModifiers |= cmdKey;
	if([prefDropControl state] == NSOnState)
		menuModifiers |= controlKey;
	if([prefDropOption state] == NSOnState)
		menuModifiers |= optionKey;
	if([prefDropShift state] == NSOnState)
		menuModifiers |= shiftKey;
	CFPreferencesSetAppValue((CFStringRef) @"MenuModifiers", [NSNumber numberWithInt: menuModifiers], (CFStringRef) @"com.mesadynamics.Amnesty");	
		
	CFPreferencesSetAppValue((CFStringRef) @"ToggleKey", [NSNumber numberWithInt: [prefToggleKey indexOfSelectedItem]], (CFStringRef) @"com.mesadynamics.Amnesty");	
	UInt32 toggleModifiers = 0;
	if([prefToggleCommand state] == NSOnState)
		toggleModifiers |= cmdKey;
	if([prefToggleControl state] == NSOnState)
		toggleModifiers |= controlKey;
	if([prefToggleOption state] == NSOnState)
		toggleModifiers |= optionKey;
	if([prefToggleShift state] == NSOnState)
		toggleModifiers |= shiftKey;
	CFPreferencesSetAppValue((CFStringRef) @"ToggleModifiers", [NSNumber numberWithInt: toggleModifiers], (CFStringRef) @"com.mesadynamics.Amnesty");	

	if(workspace == menuSpaceNone)
		CFPreferencesSetAppValue((CFStringRef) @"CurrentLayout", (CFStringRef) @"NULL", (CFStringRef) @"com.mesadynamics.Amnesty");	
	else if(workspace == menuSpaceDefault)
		CFPreferencesSetAppValue((CFStringRef) @"CurrentLayout", (CFStringRef) @"com.mesadynamics.AmnestyWidgets.plist", (CFStringRef) @"com.mesadynamics.Amnesty");	
	else if(theWorkspaces) {
		NSMenuItem* item = [theMenu itemAtIndex: 0];
		NSMenu* wm = [item submenu];
		
		item = [wm itemWithTag: workspace];

		if(item) {
			NSString* title = [NSString stringWithFormat: @"com.mesadynamics.AmnestyWidgets.%@.plist", [item title]];
			CFPreferencesSetAppValue((CFStringRef) @"CurrentLayout", (CFStringRef) title, (CFStringRef) @"com.mesadynamics.Amnesty");	
		}
	}

	// 1.0.1
	CFPreferencesSetAppValue((CFStringRef) @"ReduceCPU", [NSNumber numberWithBool: [prefReduceCPU state]], (CFStringRef) @"com.mesadynamics.Amnesty");
	
	// 1.2.1
	CFPreferencesSetAppValue((CFStringRef) @"EnableFlip", [NSNumber numberWithBool: enableFlip], (CFStringRef) @"com.mesadynamics.Amnesty");
	CFPreferencesSetAppValue((CFStringRef) @"EnableDrop", [NSNumber numberWithBool: enableDrop], (CFStringRef) @"com.mesadynamics.Amnesty");
	
	CFPreferencesAppSynchronize((CFStringRef) @"com.mesadynamics.Amnesty");
}

- (void)startModalAndIgnore:(WidgetController*)ignore
{
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller && controller != ignore && [[controller window] isVisible])
				[controller bringToShowcase];
		}
	}
}

- (void)finishModalAndIgnore:(WidgetController*)ignore
{
	CWidgetList* list = CWidgetList::GetInstance();

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			WidgetController* controller = (WidgetController*) widget->GetController();
			if(controller && controller != ignore && [[controller window] isVisible])
				[controller putAway];
		}
	}
}

// sleep notification
void powerCallback(void *refCon, io_service_t service, natural_t messageType, void *messageArgument)
{
    [(AppController *)refCon powerMessageReceived: messageType withArgument: messageArgument];
}

- (void)deregisterForSleepWakeNotification
{
	if(root_port != IO_OBJECT_NULL) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPortRef), kCFRunLoopCommonModes);
		IODeregisterForSystemPower(&notifier);
		IOServiceClose(root_port);
		IONotificationPortDestroy(notifyPortRef);
	}

	root_port = IO_OBJECT_NULL;
	notifier = IO_OBJECT_NULL;
	notifyPortRef = NULL;
}
        
- (void)powerMessageReceived:(natural_t)messageType withArgument:(void *) messageArgument
{
    switch (messageType)
    {
        case kIOMessageSystemWillSleep:
 			{
				CWidgetList* list = CWidgetList::GetInstance();
				
				for(unsigned long i = 1; i <= list->Size(); i++) {
					CWidget* widget = list->GetByIndex(i);
					if(widget) {
						WidgetController* controller = (WidgetController*) widget->GetController();
						if(controller && [[controller window] isVisible])
							[controller sleep];
					}
				}
			}
			
            IOAllowPowerChange(root_port, (long)messageArgument);
            break;
        
        case kIOMessageCanSystemSleep:
			IOAllowPowerChange(root_port, (long)messageArgument);
			break; 
        
        case kIOMessageSystemHasPoweredOn:
			{
				CWidgetList* list = CWidgetList::GetInstance();
				
				for(unsigned long i = 1; i <= list->Size(); i++) {
					CWidget* widget = list->GetByIndex(i);
					if(widget) {
						WidgetController* controller = (WidgetController*) widget->GetController();
						if(controller && [[controller window] isVisible])
							[controller wake];
					}
				}
			}
            break;
    }
}
        
- (void)registerForSleepWakeNotification
{
	if(root_port == IO_OBJECT_NULL) {
		root_port = IORegisterForSystemPower(self, &notifyPortRef, powerCallback, &notifier);
		
		if(root_port != IO_OBJECT_NULL)
			CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPortRef), kCFRunLoopCommonModes);
	}
}

@end
