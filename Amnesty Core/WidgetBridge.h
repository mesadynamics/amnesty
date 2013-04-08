//
//  WidgetBridge.h
//  Amnesty
//
//  Created by Danny Espinoza on 4/25/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "WidgetController.h"
#import "WidgetView.h"


@interface WidgetBridge : NSObject {
	WidgetView* webView;
	WebScriptObject* scriptObject;
	WidgetController* controller;

	NSMutableArray* systemCalls;
	id undefined;
	
#if defined(BuildBrowser)
	NSString* prefPath;
	NSMutableDictionary* prefDict;
#endif
	
	NSTimer* cleaner;
	
	// read only
	id identifier;
	id startuprequest; // undocumented array
	id calculator; // undocumented
	id menu;
	
	// used for internal system callbacks
	id systemEndHandler;
	id systemOutputHandler;
	id systemErrorHandler;
	
	// callbacks
	id onremove;
	id onhide;
	id onshow;
	id ondragstart;
	id ondragstop;
	id onfocus; // deprecated
	id onblur; // deprecated
	id onreceiverequest; // undocumented
}

- (id)initWithWebView:(WebView*)webview;

- (id)invokeUndefinedMethodFromWebScript:(NSString*)name withArguments:(NSArray*)args;
- (void)windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject;

- (void)setController:(id)inController;
- (void)enableUndefined;
- (void)enableCalculator;
- (void)enableSystem;
- (void)cleanSystem:(id)sender;
- (BOOL)findSystem:(id)system withHash:(unsigned)hash withCopies:(unsigned)copies;

- (void)endScripting;

- (BOOL)canRemove;
- (BOOL)canHide;
- (BOOL)canShow;
- (BOOL)canDragStart;
- (BOOL)canDragStop;
- (BOOL)canFocus;
- (BOOL)canBlur;

- (void)loadPreferences:(NSString*)bundleID;
- (void)savePreferences;

- (id)preferenceForKey:(NSString*)key;
- (void)setPreferenceForKey:(id)preference withKey:(NSString*)key;

- (void)openURL:(NSString*)url;
- (void)openApplication:(NSString*)bundleID;

- (void)prepareForTransition:(NSString*)name;
- (void)performTransition;

- (id)system:(NSString *)command withHandler:(id)handler;

// undocumented
- (void)resizeAndMoveTo:(int)x withY:(int)y withWidth:(int)width withHeight:(int)height;
- (void)setPositionOffset:(int)x withY:(int)y;
- (void)setCloseBoxOffset:(int)x withY:(int)y;
- (id)createMenu;
- (id)closestCity;

// undocumented (and unlinked)
- (void)alert:(NSString*)message;
@end
