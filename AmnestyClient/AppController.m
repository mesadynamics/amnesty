//
//  AppController.m
//  Amnesty Client
//
//  Created by Danny Espinoza on 1/4/06.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#import "AppController.h"
#import "WidgetController.h"

#include "CFontList.h"
#include "CWidget.h"
#include "WidgetUtilities.h"

extern "C" UInt32 GetCurrentKeyModifiers();

/* Example:
	<key>CFBundleName</key>
	<string>World Clock</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	
	<key>AmnestyClientStamp</key>
	<string>1137018635.066035</string>
	<key>AmnestyClientKey</key>
	<string>48D2-5FA7-E91D-E78B</string>
	<key>AmnestyClientSignature</key>
	<string>4834-7534-3503-ADD4</string>
	
	<key>AmnestyClientPath</key>
	<string>World Clock.wdgt</string>
	<key>AmnestyClientID</key>
	<string>com.apple.widget.worldclock</string>

	<key>AmnestyClientCommands</key>
	<array>
		<dict>
			<key>CommandTitle</key>
			<string>Test</string>
			<key>CommandKey</key>
			<string>t</string>
			<key>CommandString</key>
			<string>showbackside()</string>
		</dict>
	</array>
*/
 
#define kClientBundleID CFSTR("com.mesadynamics.AmnestySingles") 
 
@implementation AppController

- (id)init
{
	[super init];

	if(self) {
		commandArray = nil;
		widget = nil;
		data = nil;
		name = nil;
		path = nil;
		nameString = nil;
		pathString = nil;
		
		opener = nil;

		enableFlip = YES;
	}

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)awakeFromNib
{
	[NSApp activateIgnoringOtherApps: YES];

	macVersion = 0;
	Gestalt(gestaltSystemVersion, &macVersion);

	NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue(CFSTR("EnableFlip"), kClientBundleID);
	if(setting)
		enableFlip = [setting boolValue];
		
	[NSApp setDelegate: self];

	NSMenu* mainMenu = [NSApp mainMenu];

	[self buildCommandArray];
	[self handleMenu:mainMenu];
	
	// set the client menus to match the widget's name
	NSString* widgetName = nil;
	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	if(infoPlist) {
		widgetName = (NSString*) [infoPlist objectForKey:@"CFBundleName"];
			
		if(widgetName) {	
			NSMenuItem* appMenuItem = [mainMenu itemAtIndex:0];
			NSMenu* appMenu = [appMenuItem submenu];
			NSArray* appMenuItems = [appMenu itemArray];
			if(appMenuItems) {
				NSEnumerator* enumerator = [appMenuItems objectEnumerator];
				NSMenuItem* item;
				   
				while(item = [enumerator nextObject]) {
					NSString* title = [item title];
									
					NSRange range = [title rangeOfString:@"Amnesty Client" options:NSCaseInsensitiveSearch];
					if(range.length != 0) {
						NSMutableString* newTitle = [title mutableCopyWithZone:nil];
						[newTitle replaceOccurrencesOfString:@"Amnesty Client" withString:widgetName options:0 range:NSMakeRange(0, [newTitle length])];
						[item setTitle:newTitle];
					}
				}
			}
		}
	}

	[self openAmnesty];	
}

- (void)buildCommandArray
{
	NSMenu* mainMenu = [NSApp mainMenu];

	NSMenuItem* commandMenuItem = nil;
	NSMenu* commandMenu = nil;
	NSZone* mZone = [NSMenu menuZone];

	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	NSArray* commands = [infoPlist objectForKey:@"AmnestyClientCommands"];
	
	if(commands) {
		NSEnumerator* enumerator = [commands objectEnumerator];
		NSDictionary* cmd;
		   
		int tag = 5000; 
		   
		while(cmd = [enumerator nextObject]) {
			NSString* cmdTitle = [cmd objectForKey:@"CommandTitle"];
			NSString* cmdKey = [cmd objectForKey:@"CommandKey"];
			NSString* cmdString = [cmd objectForKey:@"CommandString"];
						
			if([cmdKey isEqualToString:@"nil"])
				cmdKey = @"";
			
			if(commandArray == nil) {
				commandArray = [NSMutableArray arrayWithCapacity:[commands count]]; 
				[commandArray retain];
			}
			
			if(cmdTitle && cmdString) {
				if(commandMenuItem == nil) {
					commandMenuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"CommandMenu", @"")
						action: @selector(menuAction:)
						keyEquivalent: @""];
											
					commandMenu	= [[NSMenu allocWithZone: mZone] initWithTitle:NSLocalizedString(@"CommandMenu", @"")];
					[commandMenu setAutoenablesItems:NO];
					[commandMenu setDelegate:(id)self];
					[commandMenuItem setSubmenu:commandMenu];
						
					[mainMenu addItem:commandMenuItem];
				}
				
				if(commandMenuItem) {
					NSMenuItem* cmdMenuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: cmdTitle
						action: @selector(menuAction:)
						keyEquivalent: cmdKey];
					
					[cmdMenuItem setTag:tag++];						
																							
					[commandMenu addItem:cmdMenuItem];
					
					NSString* commandString = [NSString stringWithString:cmdString];
					[commandString retain];
					
					[commandArray addObject:commandString];
				}
			}
		}
	}
}

- (void)handleMenu:(NSMenu*)menu
{
	[menu setDelegate:(id)self];
	
	NSArray* mainMenuItems = [menu itemArray];
	if(mainMenuItems) {
		NSEnumerator* enumerator = [mainMenuItems objectEnumerator];
		NSMenuItem* item;
		
		while(item = [enumerator nextObject]) {
			NSMenu* submenu = [item submenu];
			if(submenu)
				[self handleMenu:submenu];
		}
	}
}

- (BOOL)openAmnesty
{
	return YES;
}

- (void)closeAmnesty
{	
	CFontList* fontList = CFontList::GetInstance(false);
	if(fontList)
		fontList->Free();
}

- (BOOL)openWidget
{
	BOOL addToList = YES;
	
	NSString* widgetStamp = nil;
	NSString* widgetPath = nil;
	NSString* widgetID = nil;
	NSString* widgetName = nil;
	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	if(infoPlist) {
        // AmnestyClientKey and AmnestyClientSignature are ignored in free version

		widgetStamp = (NSString*) [infoPlist objectForKey:@"AmnestyClientStamp"];
		widgetPath = (NSString*) [infoPlist objectForKey:@"AmnestyClientPath"];
		widgetID = (NSString*) [infoPlist objectForKey:@"AmnestyClientID"];
		widgetName = (NSString*) [infoPlist objectForKey:@"CFBundleName"];
    }
    
	NSBundle* bundle = [NSBundle mainBundle];

	if([widgetPath hasPrefix:@"/"] == NO) {
		NSString* embeddedPath = [NSString stringWithFormat:@"%@/%@", [bundle resourcePath], widgetPath];
		widgetPath = embeddedPath;
	}
						
	UInt32 modifiers = GetCurrentKeyModifiers();

	BOOL didRedirect = NO;	
	BOOL didFind = NO;	
	NSString* redirectKey = [NSString stringWithFormat:@"%@-Redirect", widgetStamp];
			
	NSFileManager* fm = [NSFileManager defaultManager];
	if(widgetPath == nil || [fm fileExistsAtPath: widgetPath] == NO) {
		if((modifiers & (1<<8)) && (modifiers & (1<<11))) {
			CFPreferencesSetAppValue((CFStringRef) redirectKey, (CFStringRef) NULL, kCFPreferencesCurrentApplication);	
			CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
		}
		else {
			NSString* redirect = (NSString*) CFPreferencesCopyAppValue((CFStringRef) redirectKey, kClientBundleID);
			if(redirect) {
				if([fm fileExistsAtPath: redirect]) {
					widget = new CWidget((CFStringRef) redirect);
					
					didRedirect = YES;
				}
			}	
			
			if(widget == nil) {
				widget = [self findWidget:widgetID];

				if(widget) {
					didFind = YES;
					addToList = NO;
				}
			}
		}
		
		if(widget == nil) {
			NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"MissingTitle", @"")
				defaultButton: NSLocalizedString(@"GenericOK", @"")
				alternateButton: nil
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"MissingMessage", @""), widgetName];

			[NSApp activateIgnoringOtherApps: YES];
			[[alert window] setLevel: NSStatusWindowLevel+1];
			[alert runModal];

			NSOpenPanel* panel = [NSOpenPanel openPanel];
			NSArray* fileTypes = [NSArray arrayWithObject:@"wdgt"];
			if([panel runModalForTypes:fileTypes] == NSOKButton) {
				NSArray* filePaths = [panel filenames];
				widgetPath = [filePaths objectAtIndex:0];
				widget = new CWidget((CFStringRef) widgetPath);
				
				didRedirect = YES;

				if(widget) {
					CFPreferencesSetAppValue((CFStringRef) redirectKey, (CFStringRef) widgetPath, kClientBundleID);	
					CFPreferencesAppSynchronize(kClientBundleID);
				}	
			}
		}
	}
	else
		widget = new CWidget((CFStringRef) widgetPath);

	if(widget == nil) {
		if(didRedirect) {
			CFPreferencesSetAppValue((CFStringRef) redirectKey, (CFStringRef) NULL, kClientBundleID);	
			CFPreferencesAppSynchronize(kClientBundleID);
		}

		return NO;
	}
	
	if([widgetID isEqualToString:(NSString*)widget->GetID()] == NO) {
		NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"MismatchTitle", @"")
			defaultButton: NSLocalizedString(@"GenericQuit", @"")
			alternateButton: nil
			otherButton: nil
			informativeTextWithFormat: NSLocalizedString(@"MismatchMessage", @""), widgetName];

		[NSApp activateIgnoringOtherApps: YES];
		[[alert window] setLevel: NSStatusWindowLevel+1];
		[alert runModal];

		if(didRedirect) {
			CFPreferencesSetAppValue((CFStringRef) redirectKey, (CFStringRef) NULL, kClientBundleID);	
			CFPreferencesAppSynchronize(kClientBundleID);
		}

		return NO;
	}
    
	if(addToList) {
		CWidgetList* list = CWidgetList::GetInstance();	
		list->AddWidget(widget);
	}

	widget->Core();
		
	if(widget->IsValid() == false) {
		NSAlert* alert = nil;
		
		if(widget->IsForbidden()) {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"NoSupportTitle", @"")
				defaultButton: NSLocalizedString(@"GenericQuit", @"")
				alternateButton: nil
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"NoSupportPantherMessage", @""), widgetName];
		}
		else {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"NoSupportTitle", @"")
				defaultButton: NSLocalizedString(@"GenericQuit", @"")
				alternateButton: nil
				otherButton: nil
				informativeTextWithFormat: NSLocalizedString(@"NoSupportMessage", @""), widgetName];
		}		

		[NSApp activateIgnoringOtherApps: YES];
		[[alert window] setLevel: NSStatusWindowLevel+1];
		[alert runModal];

		widget = nil;
		return NO;
	}
		
	FindPlugins(widget->GetPath(), true);
	
	widget->LoadFonts();

	WidgetController* controller = [[WidgetController alloc] init];
	
	[controller setCompatible: (widget->GetCompatible() ? YES : NO)];

	[controller setSecurityFile: YES];
	[controller setSecurityPlugins: YES];
	[controller setSecurityJava: YES];
	[controller setSecurityNet: YES];
	[controller setSecuritySystem: YES];

	[controller setLocalFolder: widget->GetLocalFolder()];
	
	NSURL* widgeturl = (NSURL*) widget->GetWidgetURL();
	[controller setWidgetURL: widgeturl];
	
	NSURL* pluginurl = (NSURL*) widget->GetPluginURL();
	if(pluginurl) // optional
		[controller setPluginURL: pluginurl];

	NSURL* iconurl = (NSURL*) widget->GetIconURL();
	if(iconurl) // optional
		[controller setIconURL: iconurl];

	NSString* bid = (NSString*) widget->GetID();
	[controller setWidgetID: bid];
	
	NSString* pth = (NSString*) widget->GetPath();
	[controller setWidgetPath: pth];
		
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
		
	widget->SetController(controller);

	[controller prepareWidget:self];
		
	return YES;
}

- (void)handleOpen:(id)sender
{
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

- (void)handleOpenTask:(id)sender
{
	WidgetController* controller = sender;
	
	if([controller closing] == NO && [controller loaded] == NO) {
		if([controller busy] == YES) {
			[controller runWidget:self];
			[opener invalidate];
		}	
		else
			[controller loadWidget:self];
	}
}

- (void)closeWidget:(id)sender
{
	if(widget) {
		FindPlugins(widget->GetPath(), false);

		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller) {
			[controller forceQuit];
		}
	}
}

- (CWidget*)findWidget:(NSString*)wid
{
	{
		NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
		[amnestyWidgetString appendString: NSHomeDirectory()];
		[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];
		FindWidgets((CFStringRef) amnestyWidgetString, 2);
	}
	
	if(macVersion >= 0x1040) {
		NSMutableString* localWidgetString = [NSMutableString stringWithCapacity: 1024];
		[localWidgetString appendString: NSHomeDirectory()];
		[localWidgetString appendString: @"/Library/Widgets"];
		FindWidgets((CFStringRef) localWidgetString, 1);
	}

	if(macVersion >= 0x1040) {
		NSMutableString* systemWidgetString = [NSMutableString stringWithCapacity: 1024];
		[systemWidgetString appendString: NSOpenStepRootDirectory()];
		[systemWidgetString appendString: @"Library/Widgets"];
		FindWidgets((CFStringRef) systemWidgetString, 1);
	}

	CWidgetList* list = CWidgetList::GetInstance();	
	list->Sort();

	for(int i = 1; i <= list->Size(); i++) {
		CWidget* testWidget = list->GetByIndex(i);
		if(testWidget) {
			if([wid isEqualToString: (NSString*) testWidget->GetID()]) {
				return testWidget;
			}
		}
	}
	
	return nil;
}

- (NSString*)getWidgetName // key
{
	return nameString;
}

- (NSString*)getWidgetPath // signature
{
	return pathString;
}

- (NSImage*)getWidgetIcon
{
	NSImage* icon = nil;

	if(widget) {
		NSURL* url = (NSURL*) widget->GetIconURL();

		if(url) {
			icon = [[NSImage alloc] initWithContentsOfURL: url];
			[url release];
		}
	}
	
	return icon;
}

- (IBAction)minimizeAction:(id)sender
{
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller && [controller busy] == NO) {
			NSWindow* window = [controller window];
			[window miniaturize:self];
		}
	}
}

- (IBAction)refreshAction:(id)sender
{
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller && [controller busy] == NO)
			[controller manualRefresh:self];
	}
}

- (IBAction)spacesAction:(id)sender
{
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller && [controller busy] == NO) {
			NSMenuItem* item = (NSMenuItem*) sender;
			if([item state] == NSOnState)
				[controller setAllSpaces:NO];
			else
				[controller setAllSpaces:YES];
		}
	}
}

- (IBAction)getInfoAction:(id)sender
{
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller && [controller busy] == NO) {
			[controller getInfo:self];
		}	
	}
}

- (IBAction)menuAction:(id)sender
{
	NSMenuItem* item = (NSMenuItem*) sender;
	
	int tag = [item tag];
	
	WidgetController* controller = (WidgetController*) widget->GetController();
	if(controller && [controller busy])
		return;
		
	if(tag >= 5000 && tag < 6000 && commandArray)
		[controller runCommand:[commandArray objectAtIndex:(tag - 5000)]];
	else if(tag >= 4000 && tag < 5000)
		[controller setAutoUpdate:(tag - 4000)];
	
	switch(tag) {
		case 3000:
		case 3001:
		case 3002:
		case 3003:
				[controller setWindowLevel:(tag - 3000)];
			break;
	}
}

- (IBAction)aboutAction:(id)sender
{
	NSImage* icon = [self getWidgetIcon];
	
	if(icon) {
		NSDictionary* dict = [NSDictionary dictionaryWithObject:icon forKey:@"ApplicationIcon"];
		[NSApp orderFrontStandardAboutPanelWithOptions:dict];
		
		[icon release];
	}
	else
		[NSApp orderFrontStandardAboutPanel:self];
}

// NSApplication delegate
- (void)applicationWillHide:(NSNotification* )aNotification
{	
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller)
			[controller hideNow];
	}
}

- (void)applicationWillUnhide:(NSNotification* )aNotification
{	
	if(widget) {
		WidgetController* controller = (WidgetController*) widget->GetController();
		if(controller)
			[controller showNow];
	}
}

- (void)applicationWillTerminate:(NSNotification* )aNotification
{
	[self closeWidget:self];
	[self closeAmnesty];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	if([self openWidget] == NO)
		exit(1);

	opener = [NSTimer
		scheduledTimerWithTimeInterval: (double) 0.125
		target: self
		selector:@selector(handleOpen:)
		userInfo: nil
		repeats: YES];
}

// NSMenu
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	NSArray* menuItems = [menu itemArray];
	if(menuItems == nil || widget == NULL)
		return;
		
	NSEnumerator* enumerator = [menuItems objectEnumerator];
	NSMenuItem* item;
	
	while(item = [enumerator nextObject]) {
		int tag = [item tag];
		
		if(tag >= 4000 && tag < 5000) {
			BOOL active = NO;
			WidgetController* controller = nil;

			if(widget) {
				controller = (WidgetController*) widget->GetController();
				if(controller && [controller busy] == NO)
					active = YES;
			}

			if(controller && (tag - 4000) == [controller getAutoUpdate])
				[item setState: NSOnState];
			else
				[item setState: NSOffState];
			
			if(active && [controller canRefresh] == NO)
				active = NO;

			[item setEnabled:active];
		}
		else switch(tag) {
			case 3000:
			case 3001:
			case 3002:
			case 3003:
			{
				if(widget) {
					WidgetController* controller = (WidgetController*) widget->GetController();
					if(controller && (tag - 3000) == [controller getWindowLevel])
						[item setState: NSOnState];
					else
						[item setState: NSOffState];
				}

				// drop
			}
			
			default:
			{
				BOOL active = NO;
				WidgetController* controller = nil;
				
				if(widget) {
					controller = (WidgetController*) widget->GetController();
					if(controller && [controller busy] == NO)
						active = YES;
				}
				
				if(active && (tag == 2000 || tag == 2002) && [controller canRefresh] == NO)
					active = NO;
				
				[item setEnabled:active];
				
				if(tag == 2003) {
					if(macVersion >= 0x1050) {
						BOOL spaces = [controller allSpaces];
						[item setState:(spaces ? NSOnState : NSOffState)]; 
					}
					else
						[item setEnabled:NO];
				}
				
				break;
			}
		}
	}
}

// Amnesty
- (BOOL)doesEnableFlip
{
	return enableFlip;
}

@end
