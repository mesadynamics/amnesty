//
//  SinglesController.h
//  Amnesty Singles
//
//  Created by Danny Espinoza on 4/4/06.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SinglesController : NSWindowController {
	IBOutlet NSImageView* drop;
	IBOutlet NSTextField* info;
	
	IBOutlet NSImageView* preview;
	IBOutlet NSTextField* name;
	IBOutlet NSTextField* identifier;
	IBOutlet NSTextField* version;
	IBOutlet NSTextField* location;

	IBOutlet NSButtonCell* loadExternal;
	IBOutlet NSButtonCell* loadInternal;
	
	IBOutlet NSBox* widgetInfo;
	IBOutlet NSBox* singleInfo;
	
	IBOutlet NSButton* purchase;
	IBOutlet NSButton* build;
	
	IBOutlet NSPanel* advPanel;
	IBOutlet NSTableView* advTable;
	IBOutlet NSButton* advAdd;
	IBOutlet NSButton* advRemove;
	IBOutlet NSButton* advOK;
	
	IBOutlet NSButton* saveReveal;
	IBOutlet NSButton* saveLaunch;
	IBOutlet NSView* saveExtra;
	
	BOOL isUniversal;

	IBOutlet NSWindow* theAbout;
}

- (IBAction)handleFindOnDisk:(id)sender;
- (IBAction)handleAdd:(id)sender;
- (IBAction)handleRemove:(id)sender;

- (IBAction)handleBuild:(id)sender;
- (IBAction)handleHelp:(id)sender;
- (IBAction)handleAbout:(id)sender;

- (IBAction)handleAdvanced:(id)sender;
- (IBAction)handleClose:(id)sender;

- (void)setWidgetFromURL:(NSURL*)url;
- (void)setWidgetFromPath:(NSString*)urlPath;

- (void)readPreferences;
- (void)writePreferences;

@end
