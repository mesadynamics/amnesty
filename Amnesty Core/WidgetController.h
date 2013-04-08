//
//  WidgetController.h
//  Amnesty
//
//  Created by Danny Espinoza on Sun Apr 24 2005.
//  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import "WidgetWindow.h"

#if defined(FeatureFlip)
#import "WidgetFlip.h"
#endif

@interface WidgetController : NSWindowController {
    IBOutlet id webView;
	WidgetWindow* theWindow;
	
	NSTimer* autoUpdate;
	int updateInterval;
		
	NSURL* widgetURL;
	NSURL* pluginURL;
	NSURL* imageURL;
	NSURL* iconURL;
	
	NSString* widgetID;
	NSString* widgetPath;
	
	BOOL compatible;
	
	BOOL securityFile;
	BOOL securityPlugins;
	BOOL securityJava;
	BOOL securityNet;
	BOOL securitySystem;
	
	id bridge;
	id plugin; 
	
	NSString* elementFocus;
	NSMutableDictionary* elementCache;
	BOOL acceptMouse;
	
	BOOL doPosition;
	BOOL doSettings;
	BOOL didOverride;
	BOOL didTransition;
	
	BOOL isBusy;
	BOOL isLoaded;
	BOOL isClosing;
	BOOL isQuitting;
	BOOL hasControls;
	
	long isShown;
	
#if defined(FeatureFlip)
	WidgetFlip* transitionView;
#endif

	NSTrackingRectTag tracker;
	NSString* localFolder;
	NSString* widgetFolder;
	NSString* compatiblePath;

	IBOutlet NSPanel* theSettings;
	IBOutlet NSWindow* theControls;
	
	IBOutlet NSSlider* settingsOpacity;
	IBOutlet NSPopUpButton* settingsLevel;
	IBOutlet NSButton* settingsLock;
	IBOutlet NSButton* settingIgnoreMouse;
	IBOutlet NSButton* settingAllSpaces; // 1.5
	
	IBOutlet NSPopUpButton* settingsAuto;
	IBOutlet NSSlider* settingsCPU; // unused

	IBOutlet NSSlider* settingsSize; // 1.1
	IBOutlet NSSlider* settingsRotation; // 1.1

#if defined(BuildScreenSaver)
	id saver;
#endif

	SInt32 macVersion;	
}

- (id)init;
- (void)dealloc;
- (NSString *)windowNibName;
- (void)awakeFromNib;

- (void)close;
- (void)fastClose;
- (void)restore;
- (void)quit;
#if defined(BuildClient)
- (void)forceQuit;
#endif

#if defined(BuildScreenSaver)
- (void)setSaver:(id)screenSaver;
- (id)getSaver;
#endif

- (BOOL)canBringToFront;
- (BOOL)canPutAway;
- (void)bringToFront;
- (void)bringToShowcase;
- (void)putAway;

- (void)setDoPosition: (BOOL)set;
- (void)setDoSettings: (BOOL)set;

- (void)setCompatible: (BOOL)set;

- (void)setSecurityFile: (BOOL)set;
- (void)setSecurityPlugins: (BOOL)set;
- (void)setSecurityJava: (BOOL)set;
- (void)setSecurityNet: (BOOL)set;
- (void)setSecuritySystem: (BOOL)set;
- (void)setLocalFolder: (NSString*)set;

- (BOOL)busy;
- (BOOL)loaded;
- (BOOL)closing;
- (BOOL)doesAcceptMouse;

- (void)showControls;
- (void)hideControls;
- (void)startTransition:(BOOL)toBack;
- (void)endTransition;

- (void)sleep;
- (void)wake;
- (void)willHide;
- (void)willShow;
- (void)hideNow;
- (void)showNow;
- (BOOL)canRefresh;

- (void)bridgeHide:(id)sender;
- (void)bridgeShow:(id)sender;
- (void)bridgeFocus:(id)sender;
- (void)bridgeBlur:(id)sender;

- (void)runCommand:(NSString*)command;

- (void)setWidgetURL: (NSURL *)url;
- (void)setPluginURL: (NSURL *)url;
- (void)setImageURL: (NSURL *)url;
- (void)setIconURL: (NSURL *)url;

- (void)setWidgetID: (NSString *)bid;
- (void)setWidgetPath: (NSString *)path;
- (NSString *)getWidgetID;
- (NSString *)getWidgetPath;

- (void)prepareWidget:(id)sender;
- (void)loadWidget:(id)sender;
- (void)loadPlugin:(id)sender;

- (void)runWidget:(id)sender;

- (void)receivedError: (NSError *)error;
- (void)loadComplete;
- (WebDataSource *)mainDataSource;
- (void)ready:(id)sender;

- (IBAction)menuItemAction: (id)sender;
- (IBAction)closeSettings: (id)sender; 

- (IBAction)updateOpacity: (id)sender;
- (IBAction)updateSize: (id)sender; // 1.1
- (IBAction)updateRotation: (id)sender; // 1.1

- (void)updateLevel;
- (void)updateSpaces;
- (void)updateLock;
- (void)updateIgnore;

- (void)updateAppearance;
- (void)updateDisplay;
- (void)updateTimers;

- (int)getAutoUpdate;
- (void)setAutoUpdate:(int)update;
- (int)getWindowLevel;
- (void)setWindowLevel:(int)level;

- (void)setAllSpaces:(BOOL)set;
- (BOOL)allSpaces;

- (void)manualRefresh: (id)sender;
- (void)getInfo: (id)sender;
- (void)showSettings: (id)sender;
- (void)forceMenu: (id)sender;

- (void)redraw;

- (void)readPreferences;
- (void)writePreferences;

- (BOOL)verify;
- (void)verifyStamp;
- (NSString*)verifyString;

- (BOOL)checkElement:(DOMNode*)object inFrame:(WebFrame*)webFrame;
- (BOOL)touchesFrame:(id)webFrame inRectangleRegion: (NSString*)mouseRegion withRange:(NSRange)range;
- (BOOL)touchesFrame:(id)webFrame inCircleRegion: (NSString*)mouseRegion withRange:(NSRange)range;

- (NSURLRequest *)compatResource:(NSString *)path;
- (NSURLRequest *)pantherResource:(NSString *)path inBundle:(NSBundle*)bundle;
- (NSURLRequest *)localResource:(NSString *)path withLocalization:(NSString *)localization;

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end


typedef enum {
	WebDashboardBehaviorAlwaysSendMouseEventsToAllWindows,
	WebDashboardBehaviorAlwaysSendActiveNullEventsToPlugIns,
	WebDashboardBehaviorAlwaysAcceptsFirstMouse,
	WebDashboardBehaviorAllowWheelScrolling
} WebDashboardBehavior;

@interface WebView (Private)
- (void)setDrawsBackground:(BOOL)flag;
- (BOOL)drawsBackground;

- (void)_setDashboardBehavior:(WebDashboardBehavior)behavior to:(BOOL)flag;
- (BOOL)_dashboardBehavior:(WebDashboardBehavior)behavior;

// 2.0
+ (void)_setShouldUseFontSmoothing:(BOOL)f;
- (void)setProhibitsMainFrameScrolling:(BOOL)prohibits;
@end

enum {
    NSWindowCollectionBehaviorDefault = 0,
    NSWindowCollectionBehaviorCanJoinAllSpaces = 1 << 0,
    NSWindowCollectionBehaviorMoveToActiveSpace = 1 << 1
};

@interface NSWindow (Private)
- (void)setCollectionBehavior:(NSWindowCollectionBehavior)behavior;
@end

@interface WebPreferences (Private)
- (void)setCacheModel:(WebCacheModel)cacheModel;
@end


@interface NSPopUpButton (Amnesty)
- (void)selectTag:(int)tag;
@end

