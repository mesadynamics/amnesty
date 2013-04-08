//
//  Amnesty_Screen_SaverView.h
//  Amnesty Screen Saver
//
//  Created by Danny Espinoza on 8/3/05.
//  Copyright (c) 2005, Mesa Dynamics, LLC. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import "WebKit/WebKit.h"

#import "ConfigureController.h"
#import "WidgetController.h"

@interface Amnesty_Screen_SaverView : ScreenSaverView 
{
	ConfigureController* configureSheet;

	BOOL setup;

	NSView* webView;
	NSImage* image;
	
	NSTimer* opener;
	NSTimer* renderer;
	
	NSFont* theFont;
	NSFont* theSmallFont;
	NSBundle* theBundle;
	NSBezierPath* theString;
	NSBezierPath* theName;
	
	int widgetSerial;
	SInt32 macVersion;
	
	BOOL random;
	BOOL animateHyperspace;
	BOOL animatePong;
	
	//NSWindow* blankWindow;
	NSRect saverFrame;
	NSRect widgetFrame;
	
	NSRect r;
	NSPoint v;
	NSPoint d;
	
	int frameCount;
	int frameLoopCount;
	int frameLoop;
	int frameTitle;
	
	int selected;
}

- (void)checkForExit:(id)object;
- (void)resetAnimation;

- (void)openAmnesty;
- (void)readDefaults;
- (void)startAmnesty;
- (void)closeAmnesty;
- (void)openWidget;

- (void)handleOpen:(id)sender;
- (void)handleOpenTask:(id)sender;
- (void)handleRender:(id)sender;
- (void)handleFront:(id)sender;

- (void)animateWidget:(WidgetController*)controller;

- (NSBezierPath *)getAnimatedString: (NSString *)string forFont: (NSFont *)font withX:(float)x withY:(float)y;
- (BOOL) isMainScreen;
@end
