//
//  ConfigureController.m
//  Amnesty Screen Saver
//
//  Created by Danny Espinoza on 8/9/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "ConfigureController.h"
#import "Amnesty_Screen_SaverView.h"

#include "CWidget.h"

@implementation ConfigureController

- (NSString *)windowNibName
{
    return @"Main";
}

- (void)awakeFromNib
{
	ScreenSaverDefaults* defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"com.mesadynamics.AmnestyScreenSaver"];

	int animationIndex = [defaults integerForKey: @"Animation"];
	if(animationIndex >= 0 && animationIndex <= 2)
		[animation selectItemAtIndex: animationIndex];

	widgetID = [defaults stringForKey: @"Widget"];
	if(widgetID == NULL || [widgetID isEqualToString: @""]) {
		SInt32 macVersion = 0;
		Gestalt(gestaltSystemVersion, &macVersion);
		
		if(macVersion < 0x1040)
			widgetID = @"com.neometric.widget.flipclock";
		else
			widgetID = @"com.apple.widget.worldclock";
			
		animationIndex = 1;
	}
		
	if(LSFindApplicationForInfo('mDaM', CFSTR("com.mesadynamics.Amnesty"), CFSTR("Amnesty.app"), NULL, NULL) == noErr)
		[download setHidden: YES];

	NSMutableString* amnestyPrefPath = [NSMutableString stringWithCapacity: 1024];
	[amnestyPrefPath appendString: NSHomeDirectory()];
	[amnestyPrefPath appendString: @"/Library/Preferences/com.mesadynamics.Amnesty.plist"];
	if([[NSFileManager defaultManager] fileExistsAtPath: amnestyPrefPath])
		[download setHidden: YES];
		
	NSMenu* theMenu = [widget menu];
	
	CWidgetList* list = CWidgetList::GetInstance();	

	long selected = 0;
	{
		NSZone* mZone = [NSMenu menuZone];

		long index = 1;

		for(unsigned long i = 1; i <= list->Size(); i++) {
			CWidget* theWidget = list->GetByIndex(i);
			if(theWidget) {
				if(theWidget->IsValid()) {	
					NSMenuItem*  menuItem = NULL;

					NSString* name = (NSString*) theWidget->GetName();
					menuItem = [[NSMenuItem allocWithZone: mZone] initWithTitle: name
						action: @selector(menuItemAction:)
						keyEquivalent: @""];
					
					NSURL* url = (NSURL*) theWidget->GetIconURL();
					NSImage* icon = NULL;
					
					if(url) {
						icon = [[[NSImage alloc] initWithContentsOfURL: url] autorelease];
						[url release];
					}
					
					if(icon == NULL) {
						NSURL* imageURL = (NSURL*) theWidget->GetImageURL();
						if(imageURL) {
							icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
							[imageURL release];
						}
					}
					
					if(icon == NULL) {
						NSBundle* bundle = [NSBundle bundleWithIdentifier: @"com.mesadynamics.AmnestyScreenSaver"];
						icon = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"NoImage" ofType:@"png"]] autorelease];
					}
					
					if(icon) {
						NSSize iconSize;
						iconSize.width = 16;
						iconSize.height = 16;
					
						[icon setDataRetained: YES];
						[icon setScalesWhenResized: YES];
						[icon setSize: iconSize];
						[menuItem setImage: icon];
					}
						
					[menuItem setTag: theWidget->GetSerial()];
					[menuItem setTarget: self];
					[menuItem setEnabled: YES];	
					
					[theMenu insertItem: menuItem atIndex: (int) ++index];
				
					if(widgetID && [widgetID isEqualToString: (NSString*) theWidget->GetID()])
						selected = index;
						
					[menuItem release];
				}
			}
		}
	}
	
	if(selected > 1)
		[widget selectItemAtIndex: selected];
}

- (IBAction)menuItemAction: (id)sender
{
	NSMenuItem* menuItem = (NSMenuItem*) sender;
	int i = [menuItem tag];
	
	CWidgetList* list = CWidgetList::GetInstance();	
	CWidget* theWidget = list->GetBySerial(i);
	if(theWidget)
		widgetID = (NSString*) theWidget->GetID();
	else
		widgetID = @"Random";
}

- (IBAction)handleDownload: (id)sender
{
	NSURL* target = [NSURL URLWithString: @"http://www.mesadynamics.com"];
	if(target)
		LSOpenCFURLRef((CFURLRef) target, NULL);
}

- (IBAction)handleOK: (id)sender
{
	ScreenSaverDefaults* defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"com.mesadynamics.AmnestyScreenSaver"];
	
	if([widget indexOfSelectedItem] == 0)
		[defaults setObject: @"Random" forKey: @"Widget"];
	else
		[defaults setObject: widgetID forKey: @"Widget"];
		
	int animationIndex = [animation indexOfSelectedItem];
	[defaults setInteger: animationIndex forKey: @"Animation"];
	[defaults synchronize];
	
    [NSApp endSheet: [self window] returnCode: NSOKButton];
	
	Amnesty_Screen_SaverView* amnesty = (Amnesty_Screen_SaverView*) saver;
	if(amnesty)
		[amnesty resetAnimation];
}

- (IBAction)handleCancel: (id)sender
{
    [NSApp endSheet: [self window] returnCode: NSCancelButton];
}

- (void)setSaver:(ScreenSaverView*)screenSaver
{
	saver = screenSaver;
}

@end
