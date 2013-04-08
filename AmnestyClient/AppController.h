//
//  AppController.h
//  Amnesty Client
//
//  Created by Danny Espinoza on 1/4/06.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class CWidget;


@interface AppController : NSObject {
	SInt32 macVersion;
	
	NSMutableArray* commandArray;
	CWidget* widget;
	
	char* data;
	char* name;
	char* path;
	
	NSString* nameString;
	NSString* pathString;

	NSTimer* opener;

	BOOL enableFlip;
}

- (id)init;
- (void)dealloc;
- (void)awakeFromNib;

- (void)buildCommandArray;
- (void)handleMenu:(NSMenu*)menu;

- (BOOL)openAmnesty;
- (void)closeAmnesty;

- (BOOL)openWidget;
- (void)handleOpen:(id)sender;
- (void)handleOpenTask:(id)sender;
- (void)closeWidget:(id)sender;

- (CWidget*)findWidget:(NSString*)wid;

- (NSString*)getWidgetName;
- (NSString*)getWidgetPath;
- (NSImage*)getWidgetIcon;

- (IBAction)minimizeAction: (id)sender;
- (IBAction)refreshAction: (id)sender;
- (IBAction)spacesAction: (id)sender;
- (IBAction)getInfoAction: (id)sender;
- (IBAction)menuAction: (id)sender;
- (IBAction)aboutAction: (id)sender;

- (BOOL)doesEnableFlip;

@end
