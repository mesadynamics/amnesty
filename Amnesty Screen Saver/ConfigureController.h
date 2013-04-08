//
//  ConfigureController.h
//  Amnesty Screen Saver
//
//  Created by Danny Espinoza on 8/9/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>


@interface ConfigureController : NSWindowController {
	NSString* widgetID;
	
	IBOutlet NSButton* download;
	IBOutlet NSPopUpButton* widget;
	IBOutlet NSPopUpButton* animation;
	
	ScreenSaverView* saver;
}

- (IBAction)handleDownload: (id)sender;
- (IBAction)handleOK: (id)sender;
- (IBAction)handleCancel: (id)sender;

- (void)setSaver:(ScreenSaverView*)screenSaver;

@end
