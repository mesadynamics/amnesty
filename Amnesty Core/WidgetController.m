//
//  WidgetController.m
//  Amnesty
//
//  Created by Danny Espinoza on Sun Apr 24 2005.
//  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetBridge.h"
#import "WidgetController.h"

#if defined(BuildScreenSaver)
#import "Amnesty_Screen_SaverView.h"
#else
#import "AppController.h"
#endif

#import <WebKit/WebKit.h>
#import <Foundation/NSError.h>
#import <SystemConfiguration/SCNetwork.h>

extern "C" UInt32 GetCurrentKeyModifiers();
extern "C" double GetCurrentEventTime();

#include "CWidget.h"
#if defined(BuildBrowser)
#include "UBusy.h"
#endif

char amnestyCss[1024];
const char* amnestyCssTemplate = "%s\n%s\n%s\n";
const char* amnestyCssTokens[3] = {
	"html {\n\t-khtml-user-select: none;\n}\n",
	"input, select, textarea, button  {\n\t-apple-dashboard-region: dashboard-region(control rectangle);\n}\n",
	"body {\n\tcursor: default;\n}\n",
};

void AssembleCss()
{
	sprintf(
		amnestyCss,
		amnestyCssTemplate, 
		amnestyCssTokens[0],
		amnestyCssTokens[1],
		amnestyCssTokens[2]
	);
};

@implementation WidgetController

- (id)init
{
	if(self = [super init]) {
		theWindow = nil;
		
		autoUpdate = nil;
		updateInterval = -1;
						
		widgetURL = nil;
		pluginURL = nil;
		imageURL = nil;
		iconURL = nil;
		
		widgetID = nil;
		widgetPath = nil;

		compatible = NO;
		compatiblePath = nil;

		securityFile = NO;
		securityPlugins = NO;
		securityJava = NO;
		securityNet = NO;
		securitySystem = NO;
		
		bridge = nil;
		plugin = nil;
		
		elementFocus = nil;
		elementCache = nil;
		acceptMouse = YES;
		
		doPosition = YES;
		doSettings = YES;
		didOverride = NO;
		didTransition = NO;

		isBusy = NO;
		isLoaded = NO;
		isClosing = NO;
		isQuitting = NO;
		hasControls = NO;
		
		isShown = 0;
		
#if defined(FeatureFlip)
		transitionView = nil;
#endif
		
		tracker = 0;
		localFolder = nil;
		widgetFolder = nil;

#if defined(BuildScreenSaver)
		saver = nil;
#endif

		macVersion = 0;
		Gestalt(gestaltSystemVersion, &macVersion);
	}
	
	return self;
}

- (void)dealloc
{
	AmnestyLog(@"%@: controller dealloc", widgetID);
	
	// clean up
	if(tracker)
		[webView removeTrackingRect: tracker];
		
	if(elementFocus)
		[elementFocus release];
		
	if(elementCache)
		[elementCache release];
		
	if(autoUpdate)
		[autoUpdate invalidate];
					
	if(widgetFolder)
		[widgetFolder release];
		
	if(compatiblePath)
		[compatiblePath release];
		
	if(bridge)
		[bridge release];
		
	[theControls close];

	[super dealloc];
}

- (NSString *)windowNibName
{
    return @"Widget";
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ready:) name:WebViewProgressFinishedNotification object:webView];

	theWindow = (WidgetWindow*) [self window];
	//[theWindow setDelegate: self];
	// replace delegate (which can be stolen from or to) with Notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidMiniaturize:) name:NSWindowDidMiniaturizeNotification object:theWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidDeminiaturize:) name:NSWindowDidDeminiaturizeNotification object:theWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:theWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:theWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:theWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidMove:) name:NSWindowDidMoveNotification object:theWindow];

	[webView setHostWindow:theWindow];
	
	if([webView respondsToSelector:@selector(setDrawsBackground:)])
		[webView setDrawsBackground: NO];

	if([WebView respondsToSelector:@selector(_setShouldUseFontSmoothing:)])
		[WebView _setShouldUseFontSmoothing: NO];

	if([webView respondsToSelector:@selector(setProhibitsMainFrameScrolling:)])
		[webView setProhibitsMainFrameScrolling: YES];

	if([webView respondsToSelector:@selector(_setDashboardBehavior:to:)]) {
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysSendMouseEventsToAllWindows to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysAcceptsFirstMouse to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAllowWheelScrolling to:YES];
		[webView _setDashboardBehavior:WebDashboardBehaviorAlwaysSendActiveNullEventsToPlugIns to:NO];
	}
				
	[webView setEditable: NO];
	[webView setMaintainsBackForwardList: NO];

	//NSLog(@"resourceLoadDelegate:%@", [webView resourceLoadDelegate]);
	//NSLog(@"frameLoadDelegate:%@", [webView frameLoadDelegate]);
	//NSLog(@"UIDelegate:%@", [webView UIDelegate]);
	
	[webView setResourceLoadDelegate: self];
    [webView setFrameLoadDelegate: self]; 
    [webView setUIDelegate: self];
	
	if(macVersion < 0x1050) {
		[settingAllSpaces setEnabled:NO];
	}
}

- (void)close
{	
	if(isClosing)
		return;

	// kludge
	if([widgetID isEqualToString:@"com.apple.widget.translation"])
		return;

	AmnestyLog(@"%@: controller closing", widgetID);

	[self fastClose];
	
	// unhinge from main app
	CWidgetList* list = CWidgetList::GetInstance();
	CWidget* widget = list->GetByID((CFStringRef) widgetID);
	if(widget)
		widget->SetController(nil);

	if(plugin) {
		//if([plugin respondsToSelector:@selector(finalizeForWebScript)]) {
		//	[plugin finalizeForWebScript];
		//}
		
		AmnestyLog(@"%@: plugin release", widgetID);

		[plugin release];
		plugin = nil;
	}
	
	if(bridge) {
		[bridge release];
		bridge = nil;
	}	

	// detach webview
	[webView setHostWindow:nil];
	[webView removeFromSuperviewWithoutNeedingDisplay];

	[super close];
}

- (void)fastClose
{
	if(isClosing)
		return;
		
	isClosing = YES;

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self hideControls];

	if(isBusy == YES) {
#if defined(BuildBrowser)
		UBusy::NotBusy();
#endif
		isBusy = NO;
	}
	else {
		// save preferences
		if(bridge) 	
			[bridge savePreferences];
		
		[self writePreferences];
	}
	
	// dont respond to messages during close
	// [theWindow setDelegate:nil];
	
	//NSLog(@"resourceLoadDelegate:%@", [webView resourceLoadDelegate]);
	//NSLog(@"frameLoadDelegate:%@", [webView frameLoadDelegate]);
	//NSLog(@"UIDelegate:%@", [webView UIDelegate]);

	[webView setResourceLoadDelegate: nil];
    [webView setFrameLoadDelegate: nil];
    [webView setUIDelegate: nil];
	
	[webView setHidden: YES];
}

- (void)restore
{
	[self readPreferences];

	[self updateAppearance];
	[self willShow];
}

- (void)quit
{
	isQuitting = YES;
}

#if defined(BuildClient)
- (void)forceQuit
{
	[self bridgeHide:self];
	
	[[self window] orderOut:self];
	
	// save preferences
	if(bridge) 	
		[bridge savePreferences];
	
	[self writePreferences];

	// clean up temp files
	NSString* tempDir = NSTemporaryDirectory();
	if(tempDir) {
		NSFileManager* fm = [NSFileManager defaultManager];
		NSArray* contents = [fm directoryContentsAtPath:tempDir];
		NSEnumerator* enumerator = [contents objectEnumerator];
		NSString* tempFile;
		NSString* prefix = [NSString stringWithFormat:@"%@.Amnesty.", widgetID];
		
		while(tempFile = [enumerator nextObject]) {
			if([tempFile hasPrefix:prefix]) {
				NSString* tempFilePath = [NSString stringWithFormat:@"%@%@", tempDir, tempFile];
				[fm removeFileAtPath:tempFilePath handler:nil];
			}
		}
	}
}
#endif

#if defined(BuildScreenSaver)
- (void)setSaver:(id)screenSaver
{
	saver = screenSaver;
}

- (id)getSaver
{
	return saver;
}
#endif // BuildScreenSaver

- (void)setDoPosition:(BOOL)set
{
	doPosition = set;
}

- (void)setDoSettings:(BOOL)set
{
	doSettings = set;
}

- (void)setCompatible:(BOOL)set
{
	if(macVersion >= 0x1043)
		compatible = set;
}

- (void)setSecurityFile:(BOOL)set
{
	securityFile = set;
}

- (void)setSecurityPlugins:(BOOL)set
{
	securityPlugins = set;
}

- (void)setSecurityJava:(BOOL)set
{
	securityJava = set;
}

- (void)setSecurityNet:(BOOL)set
{
	securityNet = set;
}

- (void)setSecuritySystem:(BOOL)set
{
	securitySystem = set;
}

- (void)setLocalFolder:(NSString*)set
{
	localFolder = set;
}

- (BOOL)busy
{
	return isBusy;
}

- (BOOL)loaded
{
	return isLoaded;
}

- (BOOL)closing
{
	return isClosing;
}

- (BOOL)doesAcceptMouse
{
	return acceptMouse;
} 

- (void)showControls
{
#if defined(BuildBrowser)
	AppController* ac = (AppController*) [NSApp delegate];
	if([ac doesEnableDrop] == NO)
		return;

	if(imageURL) {
		NSView* view = [theControls contentView];
		NSImageView* imageView = (NSImageView*) [view viewWithTag:0];
		NSImage* image = [[[NSImage alloc] initWithContentsOfURL:imageURL] autorelease];
		[imageView setImage:image];
		[imageView setEnabled:NO];
		
		NSSize imageSize = [image size];
		NSImageRep* rep = [[image representations] objectAtIndex: 0];
		float renderedWidth = (rep ? [rep pixelsWide] : imageSize.width);
		float renderedHeight = (rep ? [rep pixelsHigh] : imageSize.height);
		
		NSRect frame = [theWindow frame];
		frame.size.width = renderedWidth;
		frame.size.height = renderedHeight;
		NSPoint anchor;
		anchor.x = frame.origin.x;
		anchor.y = frame.origin.y + frame.size.height;
		
		[theControls setFrame:frame display: NO animate: NO];
		[theControls setFrameTopLeftPoint: anchor];
		
		[theControls setAlphaValue: [theWindow alphaValue] * .10];
		[theControls setLevel: [theWindow level]];
		
#if defined(FeatureTransform)
		WidgetWindow* theTransformControls = (WidgetWindow*) theControls;
		[theTransformControls reset];

		int scaleChange = [settingsSize intValue];
		if(scaleChange != 100) {
			double scale = [settingsSize doubleValue] * .01;
			[theTransformControls scaleX: scale Y: scale];
		}
		
		int rotationChange = [settingsRotation intValue];
		if(rotationChange != 0 && rotationChange != 360) {
			double r = [settingsRotation doubleValue] * .0174532925;
			[theTransformControls rotate: r];
		}
#endif

		[theControls setIgnoresMouseEvents: YES];

		[theControls orderFront: self];
		[theControls display];

		hasControls = YES;
	}
	
#endif
}

- (void)hideControls
{
	if(hasControls) {
		[theControls orderOut: self];
		
		NSView* view = [theControls contentView];
		
		NSImageView* imageView = (NSImageView*) [view viewWithTag:0];
		[imageView removeFromSuperview];
		
		hasControls = NO;
	}
}

- (void)startTransition:(BOOL)toBack
{
	if([theWindow isVisible] == NO)
		return;
				
	didTransition = YES;	
		
	[theWindow disableFlushWindow];

#if defined(FeatureFlip)
	if(macVersion >= 0x1040) {
		NSRect content = [theWindow contentRectForFrameRect:[theWindow frame]];
		NSRect expandedContent = NSInsetRect(content, -32.0, -32.0);
		WidgetWindow* theFlipper = [[WidgetWindow alloc] initWithContentRect:expandedContent styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
		
		[theFlipper setBackgroundColor: [NSColor clearColor]];
		[theFlipper setLevel: [theWindow level]];
		[theFlipper setAlphaValue: [theWindow alphaValue]];
		[theFlipper setOpaque:NO];
		[theFlipper setHasShadow: NO];
		[theFlipper setMovableByWindowBackground: NO];
		[theFlipper setAcceptsMouseMovedEvents: NO];
		[theFlipper setIgnoresMouseEvents: YES];

#if defined(FeatureTransform)
		[theFlipper reset];

		int scaleChange = [settingsSize intValue];
		if(scaleChange != 100) {
			double scale = [settingsSize doubleValue] * .01;
			[theFlipper scaleX: scale Y: scale];
		}
		
		int rotationChange = [settingsRotation intValue];
		if(rotationChange != 0 && rotationChange != 360) {
			double r = [settingsRotation doubleValue] * .0174532925;
			[theFlipper rotate: r];
		}
#endif
	
		NSView* view = [theFlipper contentView];
		NSRect frame = [theWindow frame];
		frame.origin.x = 0.0;
		frame.origin.y = 0.0;
		frame.size.width += 64.0;
		frame.size.height += 64.0;
		
		transitionView = [[WidgetFlip alloc] initWithFrame:frame];
		[transitionView initAnimationForWindow:theWindow andView:webView];
		
		[transitionView setHidden:NO];
		[view addSubview:transitionView];
		[transitionView release];

		[transitionView startAnimation:toBack];
	}
#endif		

	[webView setHidden:YES];
}

- (void)endTransition
{
	if(didTransition) {
		didTransition = NO;
		
		[webView setHidden:NO];
		
#if defined(FeatureFlip)
		if(transitionView) {
			if([transitionView endAnimation])
				return;
		}
#endif

		[theWindow enableFlushWindow];
		[webView setNeedsDisplay:YES];
	}
}

- (void)sleep
{
	if(isBusy || isClosing)
		return;
		
	if(autoUpdate) {
		[autoUpdate invalidate];
		autoUpdate = nil;
	}
}

- (void)wake
{
	if(isBusy || isClosing)
		return;
			
	updateInterval = -1;
	[self updateTimers];
}

- (void)willHide
{
	if(isBusy || isClosing)
		return;
		
	if(autoUpdate) {
		[autoUpdate invalidate];
		autoUpdate = nil;
	}
		
#if defined(BuildBrowser)
	[self putAway];
#endif
	
	[self hideNow];
}

- (void)willShow
{
	if(isBusy || isClosing)
		return;
		
#if defined(BuildBrowser)
	[self putAway];
#endif

	[self showNow];
	
	updateInterval = -1;
	[self updateTimers];
}

- (void)hideNow
{
	if(isBusy || isClosing)
		return;
		
	if(--isShown == 0) {		
#if defined(BuildBrowser)
		// this is ugly, but ee likes to trash the statusitem menu (assumes its running in own space)	
		if(widgetID && [widgetID isEqualToString:@"com.ambrosiasw.widget.easyenvelopes"])
			return;
#endif

		if(isQuitting)
			[self bridgeHide:self];
		else
			[self performSelectorOnMainThread: @selector(bridgeHide:) withObject: self waitUntilDone:NO];			
	}
}

- (void)showNow
{
	if(isBusy || isClosing)
		return;
		
	if(++isShown == 1) {
		if(isQuitting)
			[self bridgeShow:self];
		else
			[self performSelectorOnMainThread: @selector(bridgeShow:) withObject: self waitUntilDone:NO];
	}
}

- (BOOL)canRefresh
{
	BOOL canRefresh = NO;
	if(bridge && [bridge canShow] /* && [bridge canHide] */)
		canRefresh = YES;
		
	return canRefresh;
}

- (void)runCommand:(NSString*)command
{
	if(isBusy || isClosing)
		return;
		
#if defined(BuildClient)
	if(bridge) {
		WebScriptObject* win = [webView windowScriptObject];
		if(win)
			[win evaluateWebScript:command];
	}
#endif	
}

- (void)bridgeHide:(id)sender
{
	if(isBusy || isClosing)
		return;

	if(bridge) {
		if([bridge canHide]) {
			WebScriptObject* win = [webView windowScriptObject];
			if(win)
				[win evaluateWebScript: @"widget.onhide()"];
		}
	}
}

- (void)bridgeShow:(id)sender
{
	if(isBusy || isClosing)
		return;
	
	if(bridge) {
		if([bridge canShow]) {
			WebScriptObject* win = [webView windowScriptObject];
			if(win)
				[win evaluateWebScript: @"widget.onshow()"];
		}
	}	
}

- (void)bridgeFocus:(id)sender
{
	if(isBusy || isClosing)
		return;

	if(bridge) {
		if([bridge canFocus]) {
			WebScriptObject* win = [webView windowScriptObject];
			if(win)
				[win evaluateWebScript: @"widget.onfocus()"];
		}
	}	
}

- (void)bridgeBlur:(id)sender
{
	if(isBusy || isClosing)
		return;

	if(bridge) {
		if([bridge canBlur]) {
			WebScriptObject* win = [webView windowScriptObject];
			if(win)
				[win evaluateWebScript: @"widget.onblur()"];
		}
	}	
}

- (void)setWidgetURL:(NSURL *)url
{
	widgetURL = url;
}

- (void)setPluginURL:(NSURL *)url
{
	pluginURL = url;
}

- (void)setImageURL:(NSURL *)url
{
	imageURL = url;
}

- (void)setIconURL:(NSURL *)url
{
	iconURL = url;
}

- (void)setWidgetID:(NSString* )bid
{
	widgetID = bid;
}

- (void)setWidgetPath:(NSString* )path
{
	widgetPath = path;
}

- (NSString *)getWidgetID
{
	return widgetID;
}

- (NSString *)getWidgetPath
{
	return widgetPath;
}

- (void)windowDidMiniaturize:(NSNotification *)aNotification
{
	[self hideNow];
}

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
	[self showNow];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	AmnestyLog(@"%@: window became key", widgetID);
	
	if(isBusy || isClosing)
		return;
		
	[self redraw];

	[self performSelectorOnMainThread: @selector(bridgeFocus:) withObject: self waitUntilDone:NO];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	AmnestyLog(@"%@: window resigned key", widgetID);

	if(isBusy || isClosing)
		return;

	[self redraw];
		
	[self performSelectorOnMainThread: @selector(bridgeBlur:) withObject: self waitUntilDone:NO];
}

- (void)windowDidResize:(NSNotification*)aNotification  
{
	AmnestyLog(@"%@: window did resize", widgetID);

	if(tracker)
		[webView removeTrackingRect: tracker];

	/*NSSize windowSize = [[self window] frame].size;
	NSLog(@"window size: %.0f,%.0f", windowSize.width, windowSize.height);

	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];
	NSSize frameSize = [mainFrameView frame].size;
	NSLog(@"frame size: %.0f,%.0f", frameSize.width, frameSize.height);

	NSView* documentView = [mainFrameView documentView];
	NSSize documentSize = [documentView frame].size;
	NSLog(@"doc size: %.0f,%.0f", documentSize.width, documentSize.height);
	
    NSClipView* clipView = (NSClipView*)[documentView superview];
	if(clipView) {
		NSSize clipSize = [clipView frame].size;
		NSLog(@"clip size: %.0f,%.0f", clipSize.width, clipSize.height);

		NSScrollView* scrollView = (NSScrollView*)[clipView superview];
		if(scrollView) {
			NSSize scrollSize = [scrollView frame].size;
			NSLog(@"scroll size: %.0f,%.0f", scrollSize.width, scrollSize.height);
		}
	}*/
		
	NSRect frame = [theWindow frame];
	frame.origin.x = 0.0;
	frame.origin.y = 0.0;	
	tracker = [webView addTrackingRect: frame owner: webView userData: nil assumeInside:NO];
	
	[self redraw];
}

/*
 - (void)windowWillMove:(NSNotification*)aNotification
{
	AmnestyLog(@"%@: window will move", widgetID);
}
*/

- (void)windowDidMove:(NSNotification*)aNotification
{
	AmnestyLog(@"%@: window did move", widgetID);

	[self redraw];
		
	if([theWindow isVisible]) {
		WebFrame* mainFrame = [webView mainFrame];
		WebFrameView* mainFrameView = [mainFrame frameView];
		if(mainFrameView) {
			NSView* documentView = [mainFrameView documentView];
			if(documentView) {
				//NSPoint origin;	
				//origin.x = 0;
				//origin.y = 0;
				//[documentView scrollPoint: origin];
				
				NSRect frame = [theWindow frame];
				frame.origin.x = 0;
				frame.origin.y = 0;
				if([documentView scrollRectToVisible:frame]) {
					AmnestyLog(@"%@: window scrolled", widgetID);
					[self redraw];
				}
			}
		}
	}
}

/*
- (void)windowWillClose:(NSNotification*)aNotification
{
	AmnestyLog(@"%@: window close", widgetID);
}

- (void)windowDidUpdate:(NSNotification*)aNotification
{
	[theWindow displayIfNeeded];
}*/

- (void)prepareWidget:(id)sender
{
	UInt32 modifiers = GetCurrentKeyModifiers();

#if defined(BuildBrowser)	
	if((modifiers & (1<<9)) && (modifiers & (1<<11)))
		;
	else	
		[self readPreferences];
#else
#if defined(BuildClient)
	[settingsLevel selectTag:1];
#endif

	if((modifiers & (1<<9)))
		;
	else	
		[self readPreferences];
#endif

	[theWindow disableFlushWindow];
	[self updateAppearance];
	[theWindow orderOut:self];	
	[theWindow enableFlushWindow];

	[self showControls];
}

- (void)loadWidget:(id)sender
{
	if(isBusy)
		return;
		
	if(widgetURL) {
		AmnestyLog(@"%@: loading", widgetID);
	
#if defined(BuildBrowser)
		UBusy::Busy();
#endif
		isBusy = YES;
	
		WebFrame* mainFrame = [webView mainFrame];
		WebFrameView* mainFrameView = [mainFrame frameView];
		if(mainFrameView)
			[mainFrameView setAllowsScrolling:NO];
			
		NSString* prefID = [NSString stringWithFormat: @"amnesty.%@", widgetID];
		[webView setPreferencesIdentifier: prefID];
		WebPreferences* prefs = [webView preferences];
		
		[prefs setUserStyleSheetEnabled: YES];

		NSString* tempDir = NSTemporaryDirectory();
		if(tempDir) {
#if defined(BuildBrowser)
			NSString* tempCssPath = [NSString stringWithFormat: @"%@/Amnesty.css", tempDir];
#else
			NSString* tempCssPath = [NSString stringWithFormat: @"%@/%@.Amnesty.css", tempDir, widgetID];
#endif

			NSFileManager* fm = [NSFileManager defaultManager];
			if([fm fileExistsAtPath: tempCssPath] == NO) {
				AssembleCss();
				
				NSData* cssData = [NSData dataWithBytes: amnestyCss length: strlen((const char*) amnestyCss)];
				[fm createFileAtPath: tempCssPath contents: cssData attributes: nil];
			}
			
			if([fm fileExistsAtPath: tempCssPath]) {
				NSURL* cssURL = [NSURL fileURLWithPath: tempCssPath];
				[prefs setUserStyleSheetLocation: cssURL];
			}
		}
		
		[prefs setPlugInsEnabled: securityPlugins];
		[prefs setJavaEnabled: securityJava];
		//[prefs setPrivateBrowsingEnabled: YES];
		
		if([prefs respondsToSelector:@selector(setCacheModel:)])
			[prefs setCacheModel: WebCacheModelDocumentViewer];
		
		// load the widget as a bundle
		NSBundle* widgetBundle = [NSBundle bundleWithPath:widgetPath];
		if(widgetBundle)
			[widgetBundle load];

		// load the widget's plugin (optional)
		if(pluginURL) {
			[self performSelectorOnMainThread: @selector(loadPlugin:) withObject: self waitUntilDone:YES];
		}
	}
}

- (void)loadPlugin:(id)sender
{
	[NSApp activateIgnoringOtherApps: YES];
	
	NSBundle* bundle = [NSBundle bundleWithPath: [pluginURL path]];
	if(bundle) {
		[bundle load];
		
		Class principalClass = [bundle principalClass];
		if(principalClass && [principalClass instancesRespondToSelector:@selector(initWithWebView:)]) {
			plugin = [principalClass alloc];
		}
	}

	[NSApp activateIgnoringOtherApps: YES];
	
	if(plugin) {
		[plugin initWithWebView:webView];
		AmnestyLog(@"plugin loaded");
	}
}

- (void)runWidget:(id)sender
{
	if(isLoaded)
		return;
		
	isLoaded = YES;
	
	AmnestyLog(@"%@: running", widgetID);
	
	// this will work for a JS implemented Widget in 10.3.8
	/*NSString* HTML = [[NSString alloc] initWithContentsOfURL: widgetURL];
	if(HTML) {
		NSMutableString* injectedHTML = [[NSMutableString alloc] init];
		if(injectedHTML) {
			[injectedHTML setString: HTML];
			NSRange range = [injectedHTML rangeOfString: @"<script" options: NSCaseInsensitiveSearch];
			if(range.location != NSNotFound) {
				[injectedHTML
					insertString: @"<style type=\"text/css\"> <!--::selection { background: transparent; } --></style>"
					atIndex: range.location];

				[mainFrame loadHTMLString: injectedHTML baseURL: widgetURL];
				return;
			}
			
			[injectedHTML release];
		}
		
		[HTML release];
	}*/

	/*NSURLRequest* request = [NSURLRequest
		requestWithURL:widgetURL
		cachePolicy: NSURLRequestReloadIgnoringCacheData
		timeoutInterval: 5.0];*/
		
	WebFrame* mainFrame = [webView mainFrame];
	//[mainFrame loadRequest: request];
	NSString* htmlPage = [[NSString alloc] initWithContentsOfURL: widgetURL];
	[mainFrame loadHTMLString:htmlPage baseURL:widgetURL];
}

- (void)receivedError:(NSError *)error
{
	NSLog(@"%@", [error localizedDescription]);
}

- (void)loadComplete
{
	//WebFrame* mainFrame = [webView mainFrame];
	//WebFrameView* mainFrameView = [mainFrame frameView];
	//NSView* documentView = [mainFrameView documentView];
	
	//NSLog(@"webView %@ %d %d", webView, [webView isOpaque], [webView mouseDownCanMoveWindow]);
	//NSLog(@"mainFrameView %@ %d %d", mainFrameView, [mainFrameView isOpaque], [mainFrameView mouseDownCanMoveWindow]);
	//NSLog(@"documentView %@ %d %d", documentView, [documentView isOpaque], [documentView mouseDownCanMoveWindow]);
	
	if([self canRefresh] == NO) {
		[settingsAuto selectItemAtIndex: 0];
		[settingsAuto setEnabled:NO];
	}
		
	AmnestyLog(@"%@: ready for user input", widgetID);

	[self updateAppearance];
	[self updateTimers];
	
	[self hideControls];

	[self showNow];

	if(bridge) {
		WebScriptObject* win = [webView windowScriptObject];
		if(win) {
			// kludge
			if([widgetID isEqualToString:@"com.apple.widget.itunes"]) {
				[self manualRefresh:self];
			}	
		}
	}
				
	/*
	WebFrame* mainFrame = [webView mainFrame];
	WebFrameView* mainFrameView = [mainFrame frameView];
	if(mainFrameView) {
		NSView* documentView = [mainFrameView documentView];
		if(documentView) {
			//NSLog(@"found doc");
			[documentView setPostsFrameChangedNotifications:YES];
			[documentView setPostsBoundsChangedNotifications:YES];
		}
	}*/	

#if defined(BuildScreenSaver)
	if(saver) {
		Amnesty_Screen_SaverView* view = (Amnesty_Screen_SaverView*) saver;
		if(view) {
			[view animateWidget: self];
		}
	}
#endif

/*
#if defined(BuildClient)
	NSBitmapImageRep* bitmap = nil;
	
	if(macVersion < 0x1040) {
		[[webView window] disableFlushWindow];
		[[webView window] orderFront:self];
		[webView lockFocus];
		bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[webView bounds]];
		[webView unlockFocus];
		[[webView window] orderOut:self];
		[[webView window] enableFlushWindow];
	}
	else {
		bitmap = [webView bitmapImageRepForCachingDisplayInRect:[webView bounds]];
		[webView cacheDisplayInRect:[webView bounds] toBitmapImageRep:bitmap];
	}
	
	if(bitmap) {
		NSImage* image = [[[NSImage alloc] init] autorelease];
		[image addRepresentation:bitmap];
		[NSApp setApplicationIconImage:image];
	}
#endif
*/
}

- (WebDataSource *)mainDataSource
{
    return [[webView mainFrame] dataSource];
}

- (IBAction)closeSettings: (id)sender
{
	[NSApp stopModal];
	
	[self updateAppearance];
	[self updateTimers];
	
	if(didOverride == YES)
		didOverride = NO;

	[self writePreferences];
}

- (IBAction)updateOpacity: (id)sender
{
	[theWindow setAlphaValue: [settingsOpacity floatValue]];
}

- (IBAction)updateSize: (id)sender
{
#if defined(FeatureTransform)
	[theWindow reset];

	int scaleChange = [settingsSize intValue];
	if(scaleChange != 100) {
		double scale = [settingsSize doubleValue] * .01;
		[theWindow scaleX: scale Y: scale];
	}
	
	int rotationChange = [settingsRotation intValue];
	if(rotationChange != 0 && rotationChange != 360) {
		double r = [settingsRotation doubleValue] * .0174532925;
		[theWindow rotate: r];
	}
#endif	
}

- (IBAction)updateRotation: (id)sender
{
#if defined(FeatureTransform)
	[theWindow reset];

	int scaleChange = [settingsSize intValue];
	if(scaleChange != 100) {
		double scale = [settingsSize doubleValue] * .01;
		[theWindow scaleX: scale Y: scale];
	}
	
	int rotationChange = [settingsRotation intValue];
	if(rotationChange != 0 && rotationChange != 360) {
		double r = [settingsRotation doubleValue] * .0174532925;
		[theWindow rotate: r];
	}
#endif
}

- (void)updateLevel
{
#if defined(BuildScreenSaver)
	[theWindow setLevel: kCGMinimumWindowLevel];
#else
	int level = [[settingsLevel selectedItem] tag];

	switch(level) {
		case 0:
			[theWindow setLevel: NSStatusWindowLevel];
			break;
			
		case 1:
			[theWindow setLevel: NSNormalWindowLevel];
			break;
			
		case 2:
			[theWindow setLevel: kCGDesktopIconWindowLevel];
			break;
			
		case 3:
			if(widgetID && [widgetID isEqualToString:@"com.ambrosiasw.widget.easyenvelopes"])
				[theWindow setLevel: NSStatusWindowLevel];
			else
				[theWindow setLevel: NSPopUpMenuWindowLevel]; // NSStatusWindowLevel
			break;
	}		
#endif
}

- (void)updateSpaces
{
    if(macVersion >= 0x1050) {
		int spaces = [settingAllSpaces state];
		if(spaces == NSOnState)
			[(id)[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		else
			[(id)[self window] setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	}
}

	
- (void)updateDisplay
{
	//if([settingIgnoreMouse state] == NSOnState)	
		[theWindow orderFront: self];
	//else
		[theWindow makeKeyWindow];
		
	[self redraw];
}

- (void)updateAppearance
{
	[self updateLock];
	[self updateIgnore];
	[self updateLevel];
	[self updateSpaces];
	[self updateDisplay];
	
	[self updateOpacity: self];
	[self updateSize: self];
}

- (void)updateTimers
{
	int newUpdateInterval = [[settingsAuto selectedItem] tag];
	if(newUpdateInterval != updateInterval) {
		updateInterval = newUpdateInterval;

		if(autoUpdate)
			[autoUpdate invalidate];
		
		if(newUpdateInterval == 0)
			autoUpdate = nil;
		else
			autoUpdate = [NSTimer
				scheduledTimerWithTimeInterval: (double) updateInterval * 60.0
				target: self
				selector:@selector(manualRefresh:)
				userInfo: nil
				repeats: YES];
	}
}

- (int)getAutoUpdate
{
	return [[settingsAuto selectedItem] tag];
}

- (void)setAutoUpdate:(int)update
{
	int item = 0;
	
	switch(update) {
		case 1:			item = 2;		break;
		case 5:			item = 3;		break;
		case 10:		item = 4;		break;
		case 15:		item = 5;		break;
		case 30:		item = 6;		break;

		case 60:		item = 8;		break;
		case 120:		item = 9;		break;
		case 240:		item = 10;		break;
		case 480:		item = 11;		break;
		case 720:		item = 12;		break;
	}

	[settingsAuto selectItemAtIndex:item];
	[self updateTimers];
}
	
- (int)getWindowLevel
{
	int level = [[settingsLevel selectedItem] tag];
	return level;
}

- (void)setWindowLevel:(int)level
{
	[settingsLevel selectTag:level];
	[self updateLevel];
}

- (void)setAllSpaces:(BOOL)set
{
	[settingAllSpaces setState:(set ? NSOnState: NSOffState)];
	[self updateSpaces];
}

- (BOOL)allSpaces
{
	return ([settingAllSpaces state] == NSOnState ? YES : NO);
}


/*- (void)walkFrames:(WebFrame*)frame
{
	WebDataSource* dataSource = [frame dataSource];
	NSEnumerator* enumerator = [[dataSource subresources] objectEnumerator];
	WebResource* resource;
	
	while(resource = [enumerator nextObject]) {
		NSURL* resourceURL = [resource URL];
		if([[resourceURL scheme] isEqualTo:@"http"]) {
			NSLog(@"%@:", resourceURL);
			NSData* data = [resource data];
			NSString* dataString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			NSLog(@"%@", dataString);
		}
		else
			NSLog(@"-%@", resourceURL);
	}

	{
		NSArray* frames = [frame childFrames];
		NSEnumerator* enumerator = [frames objectEnumerator];
		WebFrame* child;
		
		while((child = [enumerator nextObject])) {
			[self walkFrames:child];
		}
	}
}*/

- (void)manualRefresh:(id)sender
{
	//WebFrame* mainFrame = [webView mainFrame];
	//[self walkFrames:mainFrame];

	AmnestyLog(@"%@: update", widgetID);

	[self hideNow];
	[self showNow];
}

- (void)getInfo:(id)sender
{
	BOOL omitLocation = NO;

#if defined(BuildClient)
	NSString* path = widgetPath;
	
	NSBundle* bundle = [NSBundle mainBundle];
	if([path hasPrefix:[bundle resourcePath]]) {
		omitLocation = YES;
	}
#endif

	CWidgetList* list = CWidgetList::GetInstance();
	CWidget* widget = list->GetByID((CFStringRef) widgetID);
	if(widget) {
		NSAlert* alert = nil;
		
		if(omitLocation) {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"InfoTitle", @"")
					defaultButton: NSLocalizedString(@"InfoOK", @"")
					alternateButton: nil
					otherButton: nil
					informativeTextWithFormat: @"%@:\n%@\n\n%@:\n%@\n\n%@:\n%@\n",
						 NSLocalizedString(@"InfoMessage1", @""),
						(NSString*) widget->GetName(), 
						 NSLocalizedString(@"InfoMessage2", @""),
						(NSString*) widget->GetID(), 
						 NSLocalizedString(@"InfoMessage3", @""),
						(NSString*) widget->GetVersion()
					];
		}
		else {
			alert = [NSAlert alertWithMessageText: NSLocalizedString(@"InfoTitle", @"")
					defaultButton: NSLocalizedString(@"InfoOK", @"")
					alternateButton: nil
					otherButton: nil
					informativeTextWithFormat: @"%@:\n%@\n\n%@:\n%@\n\n%@:\n%@\n\n%@:\n%@\n",
						 NSLocalizedString(@"InfoMessage1", @""),
						(NSString*) widget->GetName(), 
						 NSLocalizedString(@"InfoMessage2", @""),
						(NSString*) widget->GetID(), 
						 NSLocalizedString(@"InfoMessage3", @""),
						(NSString*) widget->GetVersion(), 
						 NSLocalizedString(@"InfoMessage4", @""),
						widgetPath
					];
		}
		
		if(iconURL) {
			NSImage* icon = [[[NSImage alloc] initWithContentsOfURL: iconURL] autorelease];

			if(icon)
				[alert setIcon: icon];
			else {
				icon = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];

				if(icon)
					[alert setIcon: icon];
			}
		}
		
			
		[NSApp activateIgnoringOtherApps: YES];

		[alert beginSheetModalForWindow: theWindow modalDelegate: self didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:) contextInfo: nil];
	}
}

- (void)showSettings:(id)sender
{
	if(didOverride == YES) {
		[self updateOpacity: self];
		[self updateSize: self];
		//[self updateRotation: self];
	}
	
	//updateInterval = [[settingsAuto selectedItem] tag];

	[NSApp activateIgnoringOtherApps: YES];

	[NSApp beginSheet: theSettings
		modalForWindow: theWindow
		modalDelegate: nil
		didEndSelector: nil 
		contextInfo: nil];
		
	[NSApp runModalForWindow: theSettings];
	
	[NSApp endSheet: theSettings];
	[theSettings orderOut: self];
}

- (void)forceMenu:(id)sender
{
	NSRect frame = [theWindow frame];
	NSPoint where;
	where.x = 0;
	where.y = frame.size.height;
	
	NSEvent* mouseDownEvent = [NSEvent  
		mouseEventWithType:NSLeftMouseDown location:where
		modifierFlags:nil timestamp:GetCurrentEventTime()  
		windowNumber: [theWindow windowNumber] context:[theWindow graphicsContext] eventNumber: nil clickCount:1  
		pressure:nil];
		
	NSArray* items = [self webView:webView contextMenuItemsForElement:nil defaultMenuItems:nil];
	if(items) {
		NSZone* mZone = [NSMenu menuZone];
		NSMenu* submenu = [[NSMenu allocWithZone:mZone] initWithTitle: widgetID];

		NSEnumerator* enumerator = [items objectEnumerator];
		NSMenuItem* anObject;
		
		while((anObject = [enumerator nextObject]))
			[submenu addItem:anObject];
			
		[NSMenu popUpContextMenu:submenu withEvent:mouseDownEvent forView:webView];
	}
}

- (void)redraw
{
	[webView setNeedsDisplay: YES];

	/*	
	if([theWindow isVisible])
		[window displayIfNeeded];*/
}

- (BOOL)canBringToFront
{
	if([theWindow isVisible] && didOverride == NO)
		return YES;
		
	return NO;
}

- (BOOL)canPutAway
{
	if(didOverride == YES)
		return YES;
		
	return NO;
}

- (void)bringToFront
{
	if([theWindow isVisible] && didOverride == NO) {
		if([settingIgnoreMouse state] == NSOnState && [theWindow ignoresMouseEvents] == YES)	
			[theWindow setIgnoresMouseEvents: NO];
			
		if([settingsLock state] == NSOnState)
			[theWindow setLocked:NO];

		[theWindow setAlphaValue: 1.0];

		int level = [[settingsLevel selectedItem] tag];
		if(level != 0) {
			if(widgetID && [widgetID isEqualToString:@"com.ambrosiasw.widget.easyenvelopes"])
				[theWindow setLevel: NSStatusWindowLevel];
			else
				[theWindow setLevel: NSPopUpMenuWindowLevel]; // NSStatusWindowLevel
		}
			
		[self redraw];	
			
		didOverride = YES;
	}
}

- (void)bringToShowcase
{
	if([theWindow isVisible] && didOverride == NO) {
		if([settingIgnoreMouse state] == NSOffState && [theWindow ignoresMouseEvents] == NO)	
			[theWindow setIgnoresMouseEvents: YES];
			
		[theWindow setAlphaValue: .5];

		[theWindow setLevel: NSModalPanelWindowLevel-1];
			
		[self redraw];	
			
		didOverride = YES;
	}
}

- (void)putAway
{
	if(didOverride == YES) {
		[self updateAppearance];
		
		didOverride = NO;
	}
}

- (void)updateLock
{
	if([settingsLock state] == NSOnState)
		[theWindow setLocked:YES];
	else
		[theWindow setLocked:NO];
}

- (void)updateIgnore
{		
	BOOL setting;
	if([settingIgnoreMouse state] == NSOnState)	
		setting = YES;
	else
		setting = NO;

	if([theWindow ignoresMouseEvents] != setting)
		[theWindow setIgnoresMouseEvents: setting];
}

- (void)readPreferences
{
#if defined(BuildScreenSaver)
	return;
#else

#if defined(BuildClient)
	NSString* com = (NSString*) kCFPreferencesCurrentApplication;
	NSString* wid = widgetID;
	
	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	if(infoPlist) {
		NSString* stamp = (NSString*) [infoPlist objectForKey:@"AmnestyClientStamp"];
		if(stamp) {
			wid = [NSString stringWithFormat:@"%@", stamp];
		}
	}
#endif

#if defined(BuildBrowser)
	int version = 0;
	{
		NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) @"PrefVersion", (CFStringRef) @"com.mesadynamics.Amnesty");
		if(setting)
			version = [setting intValue];
	}
	
	NSString* com = nil; 

	if(version && version < 80)
		com = @"com.mesadynamics.Amnesty";
	else {
		AppController* ac = (AppController*) [NSApp delegate];
		com = [ac workspaceName];
		if(com == nil)
			return;
	}
	
	NSString* wid = widgetID;
#endif

	if(doPosition) {
		NSNumber* x = nil;
		NSNumber* y = nil;
		NSNumber* y2 = nil;
		
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetX"];
			x = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);	
		}
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetY"];
			y = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
		}
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetY2"];
			y2 = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);	
		}
		
		if(x && y) {
			NSPoint frameSize;
			frameSize.x = (float) [x floatValue];
			frameSize.y = (float) [y floatValue];
			
			if(y2) {
				frameSize.y = (float) [y2 floatValue];
				[theWindow setFrameTopLeftPoint: frameSize];
			}
			else	
				[theWindow setFrameOrigin: frameSize];
		}

		/*NSScreen* screen = [theWindow screen];
		if(screen == nil) {
			NSScreen* screen = [NSScreen mainScreen];
			NSRect screenRect = [screen frame];
			NSRect windowRect = [theWindow frame];
				
			if(windowRect.origin.x + windowRect.size.width < screenRect.origin.x + 4)
				windowRect.origin.x = screenRect.origin.x;
			else if(windowRect.origin.x > screenRect.origin.x + screenRect.size.width + 4)
				windowRect.origin.x = (screenRect.origin.x + screenRect.size.width) - windowRect.size.width;
				
			if(windowRect.origin.y + windowRect.size.height < screenRect.origin.y + 4)
				windowRect.origin.y = screenRect.origin.y;
			else if(windowRect.origin.y > screenRect.origin.y + screenRect.size.height - 4)
				windowRect.origin.y = (screenRect.origin.y + screenRect.size.height) - windowRect.size.height;
				
			[theWindow setFrame: windowRect display: NO animate: NO];	
		}*/
	}
	
	if(doSettings) {
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetLevel"];
			NSNumber* level = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(level)
				[settingsLevel selectTag: [level intValue]];
		}
		
		// 1.5
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetSpaces"];
			NSNumber* spaces = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(spaces)
				[settingAllSpaces setState:[spaces intValue]];
		}
		
#if defined(BuildBrowser)
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetOpacity"];
			NSNumber* opacity = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(opacity)
				[settingsOpacity setFloatValue: [opacity floatValue]];
		}
		
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetLock"];
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(setting)
				[settingsLock setState: [setting intValue]];
		}
		
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetIgnore"];
			NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(setting)
				[settingIgnoreMouse setState: [setting intValue]];
		}

		// 1.1
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetSize"];
			NSNumber* size = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(size)
				[settingsSize setDoubleValue: [size doubleValue]];
		}
		
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetRotation"];
			NSNumber* rotation = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(rotation) {
				[settingsRotation setDoubleValue: [rotation doubleValue]];
			}
		}
#endif		

		// .80b
		{
			NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
			[key appendString: wid];
			[key appendString: @"-WidgetUpdate"];
			NSNumber* level = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) com);
			if(level)
				[settingsAuto selectItemAtIndex: [level intValue]];
		}
	}
#endif	
}

-(void)writePreferences
{
#if defined(BuildScreenSaver)
	return;
#else

#if defined(BuildClient)
	NSString* com = (NSString*) kCFPreferencesCurrentApplication;
	NSString* wid = widgetID;
	
	NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
	if(infoPlist) {
		NSString* stamp = (NSString*) [infoPlist objectForKey:@"AmnestyClientStamp"];
		if(stamp) {
			wid = [NSString stringWithFormat:@"%@", stamp];
		}
	}
#endif

#if defined(BuildBrowser)
	AppController* ac = (AppController*) [NSApp delegate];
	NSString* com = [ac workspaceName];
	if(com == nil)
		return;
		
	NSString* wid = widgetID;
#endif

	NSRect frame = [theWindow frame];

	{
		NSNumber* x = [NSNumber numberWithFloat: frame.origin.x];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetX"];
		CFPreferencesSetAppValue((CFStringRef) key, x, (CFStringRef) com);	
	}
	{
		NSNumber* y = [NSNumber numberWithFloat: frame.origin.y];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetY"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	{
		NSNumber* y = [NSNumber numberWithFloat: frame.origin.y + frame.size.height];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetY2"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
	{
		int level = [[settingsLevel selectedItem] tag];
		NSNumber* y = [NSNumber numberWithInt: level];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetLevel"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
	{
		NSNumber* y = [NSNumber numberWithBool: [settingAllSpaces state]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetSpaces"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
#if defined(BuildBrowser)
	{
		NSNumber* y = [NSNumber numberWithFloat: [settingsOpacity floatValue]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetOpacity"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
	{
		NSNumber* y = [NSNumber numberWithBool: [settingsLock state]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetLock"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}

	{
		NSNumber* y = [NSNumber numberWithBool: [settingIgnoreMouse state]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetIgnore"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}

	// 1.1
	{
		NSNumber* y = [NSNumber numberWithDouble: [settingsSize doubleValue]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetSize"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
	{
		NSNumber* y = [NSNumber numberWithDouble: [settingsRotation doubleValue]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetRotation"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
#endif

	// .80b
	{
		NSNumber* y = [NSNumber numberWithInt: [settingsAuto indexOfSelectedItem]];
		NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
		[key appendString: wid];
		[key appendString: @"-WidgetUpdate"];
		CFPreferencesSetAppValue((CFStringRef) key, y, (CFStringRef) com);	
	}
	
	CFPreferencesAppSynchronize((CFStringRef) com);
#endif
}

- (BOOL)verify
{
	if(widgetPath && [widgetPath hasPrefix: @"/Library/Widgets/"])
		return YES;

	NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
	[key appendString: widgetID];
	[key appendString: @"-WidgetAccess"];
	
	UInt32 securityFlags =
		securityFile +
		(securityPlugins * 2) +
		(securityJava * 4) +
		(securityNet * 8) +
		(securitySystem * 16);
	
	if(securityFlags == 0)
		return YES;
				
	NSNumber* setting = (NSNumber*) CFPreferencesCopyAppValue((CFStringRef) key, (CFStringRef) @"com.mesadynamics.AmnestySecurity");
	if(setting && [setting unsignedLongValue] == securityFlags)
		return YES;

	return NO;
}

- (void)verifyStamp
{
	if(widgetPath && [widgetPath hasPrefix: @"/Library/Widgets/"])
		return;
		
	NSMutableString* key = [NSMutableString stringWithCapacity: 1024];
	[key appendString: widgetID];
	[key appendString: @"-WidgetAccess"];
	
	UInt32 securityFlags =
		securityFile +
		(securityPlugins * 2) +
		(securityJava * 4) +
		(securityNet * 8) +
		(securitySystem * 16);
	
	if(securityFlags == 0)
		return;

	NSNumber* setting = [NSNumber numberWithUnsignedLong: securityFlags];
	CFPreferencesSetAppValue((CFStringRef) key, setting, (CFStringRef) @"com.mesadynamics.AmnestySecurity");	
	
	CFPreferencesAppSynchronize((CFStringRef) @"com.mesadynamics.AmnestySecurity");
}

- (NSString*)verifyString
{
	UInt32 verifyCount = 0;
	
	NSMutableString* outString = [NSMutableString stringWithCapacity:1024];
	if(securityFile)
		[outString appendFormat: @"\n\t%d. %@", (unsigned int)++verifyCount, NSLocalizedString(@"SecurityTypeFile", @"")];
	if(securityPlugins)
		[outString appendFormat: @"\n\t%d. %@", (unsigned int)++verifyCount, NSLocalizedString(@"SecurityTypePlugins", @"")];
	if(securityJava)
		[outString appendFormat: @"\n\t%d. %@", (unsigned int)++verifyCount, NSLocalizedString(@"SecurityTypeJava", @"")];
	if(securityNet)
		[outString appendFormat: @"\n\t%d. %@", (unsigned int)++verifyCount, NSLocalizedString(@"SecurityTypeNet", @"")];
	if(securitySystem)
		[outString appendFormat: @"\n\t%d. %@", (unsigned int)++verifyCount, NSLocalizedString(@"SecurityTypeSystem", @"")];
	
	[outString appendString: @"\n\n"];	
	[outString appendString:  NSLocalizedString(@"SecurityInfo", @"")];	
	[outString appendString: @"\n"];	
				
	return outString;
}

//------------------------------------------
// WebResourceLoadDelegate
//------------------------------------------

- (NSURLRequest *)compatResource:(NSString *)path
{
	if(compatiblePath == nil)
		compatiblePath = [[NSString alloc] initWithFormat:@"%@/AppleClasses/", widgetPath];

	if(compatiblePath && [path hasPrefix:compatiblePath]) {
		NSArray* components = [path pathComponents];
		NSString* pathFileName = (NSString*) [components lastObject];
		NSString* localPath = [NSString stringWithFormat: @"/System/Library/WidgetResources/AppleClasses/%@", pathFileName];
		
		if(localPath && [[NSFileManager defaultManager] fileExistsAtPath: localPath]) {
			NSURL* localURL = [NSURL fileURLWithPath: localPath];
			if(localURL) {
				NSURLRequest* localRequest = [NSURLRequest
					requestWithURL:localURL
					cachePolicy: NSURLRequestReloadIgnoringCacheData
					timeoutInterval: 5.0];

				if(localRequest)
					return localRequest;
			}
		}
	}
	
	return nil;
}

- (NSURLRequest *)pantherResource:(NSString *)path inBundle:(NSBundle*)bundle
{
	if(path) {
		NSString* bundlePath = [bundle resourcePath];
		NSArray* components = [path pathComponents];
		NSString* pathFileName = (NSString*) [components lastObject];
		NSString* localPath = [NSString stringWithFormat: @"%@/AmnestyResources/%@", bundlePath, pathFileName ];

		if(localPath && [[NSFileManager defaultManager] fileExistsAtPath: localPath]) {
			NSURL* localURL = [NSURL fileURLWithPath: localPath];
			if(localURL) {
				NSURLRequest* localRequest = [NSURLRequest
					requestWithURL:localURL
					cachePolicy: NSURLRequestReloadIgnoringCacheData
					timeoutInterval: 5.0];

				if(localRequest)
					return localRequest;
			}
		}
	}
	
	return nil;
}

- (NSURLRequest *)localResource:(NSString *)path withLocalization:(NSString *)localization
{
	if(widgetFolder == nil) {
		NSArray* widgetComponents = [widgetPath pathComponents];
		widgetFolder = (NSString*) [widgetComponents lastObject];
		[widgetFolder retain];
	}		
	
	if(widgetFolder) {
		NSArray* components = [path pathComponents];
		NSMutableArray* localComponents = [NSMutableArray arrayWithCapacity: [components count] + 1];
		[localComponents addObjectsFromArray: components];
		[localComponents insertObject: localization atIndex: [localComponents indexOfObject: widgetFolder] + 1];
		
		NSString* localPath = [NSString pathWithComponents: localComponents];
		if(localPath && [[NSFileManager defaultManager] fileExistsAtPath: localPath]) {
			NSURL* localURL = [NSURL fileURLWithPath: localPath];
			if(localURL) {
				NSURLRequest* localRequest = [NSURLRequest
					requestWithURL:localURL
					cachePolicy: NSURLRequestReloadIgnoringCacheData
					timeoutInterval: 5.0];

				if(localRequest)
					return localRequest;
			}
		}
	}
	
	return nil;
}

/*- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
	AmnestyLog(@"%@ request finished: %@", widgetID, identifier);	
}*/

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
	NSURL* url = [request URL];
	if(url == nil)
		return request;

	AmnestyLog(@"%@ request: %@", widgetID, url);
		
	NSString* scheme = [url scheme];
	NSString* path = [url path];
	
	if(path == nil)
		return request;

#if defined(BuildScreenSaver)
	NSBundle* bundle = [NSBundle bundleWithIdentifier: @"com.mesadynamics.AmnestyScreenSaver"];
#else	
	NSBundle* bundle = [NSBundle mainBundle];
#endif

#if defined(BuildBrowser)	
	if([path hasPrefix: [bundle resourcePath]]) {
		return request;
	}
#endif
										
	if(scheme && [scheme isEqualToString: @"file"]) {
		if([path hasPrefix: widgetPath]) { // local file
			if(compatible) {
				NSURLRequest* compatRequest = [self compatResource: path];
				if(compatRequest)
					return compatRequest;
			}
		
			if(localFolder) {
				NSURLRequest* localRequest = [self localResource: path withLocalization: localFolder];
				if(localRequest)
					return localRequest;
			}

			// kludges
			if([widgetID isEqualToString:@"com.apple.widget.weather"] && [path hasSuffix:@"/Weather.js"]) {
				NSString* safariPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Safari.app"];
				NSBundle* safariBundle = [NSBundle bundleWithPath:safariPath];
				NSDictionary* safariInfo = [safariBundle infoDictionary];
				NSString* safariVersion = [safariInfo objectForKey:@"CFBundleShortVersionString"];
				if([safariVersion isEqualToString:@"3.1"] && macVersion < 0x1053) {
					NSString* jsPath = [NSString stringWithFormat:@"%@/Library/Preferences/AmnestyWeather.js", NSHomeDirectory()];

					if([[NSFileManager defaultManager] fileExistsAtPath:jsPath] == NO) {
						NSString* js;
						if(macVersion >= 0x1040)
							js = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
						else
							js = [NSString stringWithContentsOfFile:path];
							
						NSMutableString* jsMod = [js mutableCopy];
						[jsMod replaceOccurrencesOfString:@"location " withString:@"wlocation " options:0 range:NSMakeRange(0, [jsMod length])];
						[jsMod replaceOccurrencesOfString:@"(location" withString:@"(wlocation" options:0 range:NSMakeRange(0, [jsMod length])];
						[jsMod replaceOccurrencesOfString:@"= location" withString:@"= wlocation" options:0 range:NSMakeRange(0, [jsMod length])];

						NSData* jsData = [jsMod dataUsingEncoding:NSUTF8StringEncoding];
						[[NSFileManager defaultManager] createFileAtPath:jsPath contents:jsData attributes:nil];
					}
					
					if([[NSFileManager defaultManager] fileExistsAtPath:jsPath]) {
						return [NSURLRequest
							requestWithURL:[NSURL fileURLWithPath:jsPath]
							cachePolicy: NSURLRequestReloadIgnoringCacheData
							timeoutInterval: 5.0];
					}
				}
			}	
			else if([widgetID isEqualToString:@"com.interdimensionmedia.widget.christmaslights"] && [path hasSuffix:@"/lights.js"] && macVersion >= 1050) {
				NSString* jsPath = [NSString stringWithFormat:@"%@/Library/Preferences/AmnestyFestiveLights.js", NSHomeDirectory()];
				
				if([[NSFileManager defaultManager] fileExistsAtPath:jsPath] == NO) {
					NSString* js;
					if(macVersion >= 0x1040)
						js = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
					else
						js = [NSString stringWithContentsOfFile:path];
					
					NSMutableString* jsMod = [js mutableCopy];
					[jsMod replaceOccurrencesOfString:@"class='NW'>" withString:@"class='NW'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='N'>" withString:@"class='N'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='NE'>" withString:@"class='NE'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='W'>" withString:@"class='W'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='E'>" withString:@"class='E'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='SW'>" withString:@"class='SW'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					[jsMod replaceOccurrencesOfString:@"class='SE'>" withString:@"class='SE'></canvas>" options:0 range:NSMakeRange(0, [jsMod length])];
					
					NSData* jsData = [jsMod dataUsingEncoding:NSUTF8StringEncoding];
					[[NSFileManager defaultManager] createFileAtPath:jsPath contents:jsData attributes:nil];
				}
				
				if([[NSFileManager defaultManager] fileExistsAtPath:jsPath]) {
					return [NSURLRequest
							requestWithURL:[NSURL fileURLWithPath:jsPath]
							cachePolicy: NSURLRequestReloadIgnoringCacheData
							timeoutInterval: 5.0];
				}
			}
		}
		else if([path hasPrefix: @"/System/Library/WidgetResources/"]) {
			if(macVersion < 0x1040) {
				NSURLRequest* pantherRequest = [self pantherResource: path inBundle: bundle];
				if(pantherRequest)
					return pantherRequest;
			}
		}
		else if([path hasSuffix: @"Amnesty.css"] == NO) { // external file
			if(securityFile == NO)
				return nil;
		}	
	}
	else if(scheme) {
		if(securityNet == NO)
			return nil;

#if 0		
		// confirm we have a connection before letting widget access net (prevents crashes) 
		NSString* host = [url host];
		if(host) {
			SCNetworkConnectionFlags flags;
			if(SCNetworkCheckReachabilityByName([host cString], &flags)) {
				if(!(flags & kSCNetworkFlagsReachable))
					return nil;
			}
		}
#endif
	}
	
	return request;
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
	return [request URL];
}

-(void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
	AmnestyLog(@"%@ error: %@ returns %@", widgetID, identifier, [error localizedDescription]);
}

-(void)webView:(WebView *)sender resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
	AmnestyLog(@"%@ authorization required for %@", widgetID, identifier);

	// we should send the proper password here, but what the hell is it?
	if(challenge) {
		id sender = [challenge sender];
		if(sender)
			[sender continueWithoutCredentialForAuthenticationChallenge: challenge];
	}
}

//------------------------------------------
// WebFrameLoadDelegate
//------------------------------------------

/*- (void)webView:(WebView *)sender willCloseFrame:(WebFrame *)frame
{
	WebScriptObject* win = [sender windowScriptObject]; 
	if(win) {
		NSArray* preferences = [win evaluateWebScript: @"widget.preferences"];
		if(preferences) {
			CFStringRef widgetName = (CFStringRef) [theWindow title];
			
			CFPreferencesSetAppValue(
				widgetName,
				preferences,
				nil);
				
			CFPreferencesAppSynchronize(nil);
		}
	}
}*/

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject
{
	UInt32 modifiers = GetCurrentKeyModifiers();

	if(windowScriptObject && bridge == nil) {
		bridge = [[WidgetBridge alloc] initWithWebView:webView];
		
		if(bridge) {
			[bridge windowScriptObjectAvailable: windowScriptObject];
			[bridge setController: self];

			if(securitySystem)
				[bridge enableSystem];
			
			if(widgetID) {
				if([widgetID isEqualToString:@"com.kalleboo.widget.classicnotepad"])
					[bridge enableUndefined];
					
				[bridge enableCalculator];

				if((modifiers & (1<<9)) && (modifiers & (1<<11)))
					;
				else
					[bridge loadPreferences: widgetID];
			}

			if(plugin) {
				[plugin windowScriptObjectAvailable: windowScriptObject];
				AmnestyLog(@"%@: plugin scripted", widgetID);
			}
		}
	}
}

- (void)ready:(id)sender
{
	if(isClosing)
		return;

	AmnestyLog(@"%@: controller ready", widgetID);

	if(isBusy == YES) {
#if defined(BuildBrowser)
		UBusy::NotBusy();
#endif
		isBusy = NO;
	}

	[self performSelectorOnMainThread:@selector(loadComplete) withObject:self waitUntilDone:NO];
}

#if 0
- (void)webView:(WebView *)sender locationChangeDone:(NSError *)error forDataSource:(WebDataSource *)dataSource
{
	if(isClosing)
		return;
		
    if(error != nil)
        [self receivedError: error];
   
	if(dataSource == [self mainDataSource]) {
		AmnestyLog(@"%@: controller locationChangeDone (main)", widgetID);

		if(isBusy == YES) {
#if defined(BuildBrowser)
			UBusy::NotBusy();
#endif
			isBusy = NO;
		}
	
       [self loadComplete];
	}
	else {
		AmnestyLog(@"%@: controller locationChangeDone", widgetID);
		[self redraw];
	}
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    [self webView:sender locationChangeDone:error forDataSource:[frame provisionalDataSource]];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [self webView:sender locationChangeDone:nil forDataSource:[frame dataSource]];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    [self webView:sender locationChangeDone:error forDataSource:[frame dataSource]];
}
#endif

//------------------------------------------
// WebUIDelegate
//------------------------------------------
- (IBAction)menuItemAction: (id)sender
{
#if defined(BuildBrowser)
	NSMenuItem* menuItem = (NSMenuItem*) sender;
	if([menuItem tag] == 'clos') {
		[self willHide];
		[theWindow orderOut: self];
		
		[self close];
	}
	else if([menuItem tag] == 'hide') {
		[self willHide];
		[theWindow orderOut : self];

		AppController* ac = (AppController*) [NSApp delegate];
		if([ac useAutoClose]) {
			[self close];
		}	
	}
	else if([menuItem tag] == 'anew') {
		[self manualRefresh: self];
	}
	else if([menuItem tag] == 'info') {
		[self getInfo:self];
	}
	else if([menuItem tag] == 'sets') {
		[self showSettings:self];
	}
#endif // BuildBrowser
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
#if defined(BuildBrowser)
	BOOL addRefreshItem = [self canRefresh];
	NSZone* mZone = [NSMenu menuZone];
	
	NSMenuItem* menuItem0 = nil;
	
	if(addRefreshItem) {
		menuItem0 =[[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetRefresh", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
		[menuItem0 setTag: 'anew'];
	}

	NSMenuItem* menuItem1 = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetSettings", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
	[menuItem1 setTag: 'sets'];

	NSMenuItem* menuItem2 = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetHide", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
	[menuItem2 setTag: 'hide'];
	
	NSMenuItem* menuItem3 = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetClose", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
	[menuItem3 setTag: 'clos'];
	
	NSMenuItem* menuItem4 = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetInfo", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
	[menuItem4 setTag: 'info'];
	
	/*NSMenuItem* menuItem5 = [[NSMenuItem allocWithZone: mZone] initWithTitle: NSLocalizedString(@"WidgetCopy", @"")
		action: @selector(menuItemAction:)
		keyEquivalent: @""];
	[menuItem5 setTag: 'copy'];*/
	
	NSArray* customMenu = nil;
	if(addRefreshItem)
		customMenu = [NSArray arrayWithObjects: menuItem2, [NSMenuItem separatorItem], menuItem0, /*menuItem5,*/ [NSMenuItem separatorItem], menuItem1, menuItem4, [NSMenuItem separatorItem], menuItem3, nil];
	else
		customMenu = [NSArray arrayWithObjects: menuItem2, /*menuItem5,*/ [NSMenuItem separatorItem], menuItem1, menuItem4, [NSMenuItem separatorItem], menuItem3, nil];

	return customMenu;
#else
	return nil;
#endif // BuildBrowser
}

- (unsigned)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragDestinationActionDHTML;
}

- (unsigned)webView:(WebView *)webView dragSourceActionMaskForPoint:(NSPoint)point
{
	return WebDragSourceActionDHTML;
}

/*
- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard
{
	//NSLog([NSString stringWithFormat: @"%d", action]);
}

- (BOOL)webView:(WebView *)sender shouldPerformAction:(SEL)action fromSender:(id)fromObject
{
	//NSLog(@"actionCheck");
	return NO;
}*/

#if 0
- (BOOL)webViewIsResizable:(WebView *)sender
{
	return YES;
}

- (void)webView:(WebView *)sender setFrame:(NSRect)frame
{
	//NSLog(@"frame");
}


- (void)webView:(WebView *)sender setContentRect:(NSRect)contentRect
{
	//NSLog(@"content");
}
#endif

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(unsigned int)modifierFlags
{
	BOOL mouseMovesWindow = YES;
	
	if([settingsLock state] == NSOnState)
		return;
				
	if(elementInformation) {
		DOMElement* object = [elementInformation objectForKey: WebElementDOMNodeKey]; 
		
		if(object) {
			NSString* objectID = nil;
			
			if([object respondsToSelector:@selector(stringRepresentation:)])
				objectID = [object stringRepresentation];
			else
				objectID = [object description];
							
			if(objectID && (elementFocus == nil || [elementFocus isEqual: objectID] == NO)) {
				if(elementFocus)
					[elementFocus release];
					
				elementFocus = [[NSString alloc] initWithString: objectID];
				
				BOOL iterate = YES;
				if(elementCache) {
					NSNumber* cachedValue = [elementCache objectForKey:objectID];
					if(cachedValue) {
						mouseMovesWindow = [cachedValue boolValue];
						iterate = NO;
					}
				}
				
				if(iterate) {
					WebFrame* webFrame = [elementInformation objectForKey: WebElementFrameKey];
					mouseMovesWindow = [self checkElement:object inFrame:webFrame];
					
					if(elementCache == nil)
						elementCache = [[NSMutableDictionary alloc] initWithCapacity:0];
						
					if(elementCache) {
						NSNumber* cachedValue = [NSNumber numberWithBool:mouseMovesWindow];
						[elementCache setObject:cachedValue forKey:objectID];
					}
				}
								
				if(mouseMovesWindow != acceptMouse) {
					acceptMouse = mouseMovesWindow;
					
					[theWindow tweak];
				}
			}
		}
	}
}

- (BOOL)checkElement:(DOMNode*)object inFrame:(WebFrame*)webFrame
{
	DOMNode* traverse = object;
	
	while(traverse) {
		if([traverse isKindOfClass:[DOMElement class]]) {
			DOMCSSStyleDeclaration* style = [webView computedStyleForElement: (DOMElement*)traverse pseudoElement: nil];
			if(style) {
				NSString* mouseRegion = [style getPropertyValue: @"-apple-dashboard-region"];
				if(mouseRegion && [mouseRegion hasSuffix: @")"]) {
					NSRange range = [mouseRegion rangeOfString: @"dashboard-region(control rectangle "];
					if(range.location != NSNotFound) {
						if([self touchesFrame: webFrame inRectangleRegion: mouseRegion withRange: range])
							return NO;
					}
					else {
						range = [mouseRegion rangeOfString: @"dashboard-region(control circle "];
						if(range.location != NSNotFound) {
							if([self touchesFrame: webFrame inCircleRegion: mouseRegion withRange: range])
								return NO;
						}
						else
							return NO;
					}
				}
			}
		}
		
		traverse = [traverse parentNode];
	}
	
	return YES;
}

- (BOOL)touchesFrame:(id)webFrame inRectangleRegion:(NSString*)mouseRegion withRange:(NSRange)range
{
	BOOL computeArea = NO;
	
	float offsetTop = 0.0;
	float offsetRight = 0.0;
	float offsetBottom = 0.0;
	float offsetLeft = 0.0;

	NSRange parameterRange;
	parameterRange.location = range.length;
	parameterRange.length = [mouseRegion length] - (range.length + 1);
	NSString* parameterString = [NSString stringWithFormat: @"%@ ", [mouseRegion substringWithRange: parameterRange]];
	
	if(parameterString) {
		NSArray* parameters = [parameterString componentsSeparatedByString: @"px "];
		if(parameters) {
			NSString* top = (NSString*) [parameters objectAtIndex: 0];
			if(top && [top isEqualToString: @"0"] == NO) {
				offsetTop = [top floatValue];
				computeArea = true;
			}

			NSString* right = (NSString*) [parameters objectAtIndex: 1];
			if(right && [right isEqualToString: @"0"] == NO) {
				offsetRight = [right floatValue];
				computeArea = true;
			}

			NSString* bottom = (NSString*) [parameters objectAtIndex: 2];
			if(bottom && [bottom isEqualToString: @"0"] == NO) {
				offsetBottom = [bottom floatValue];
				computeArea = true;
			}

			NSString* left = (NSString*) [parameters objectAtIndex: 3];
			if(left && [left isEqualToString: @"0"] == NO) {
				offsetLeft = [left floatValue];
				computeArea = true;
			}
		}
	}
	
	if(computeArea) {
		NSView* frameView = [webFrame frameView];
		NSRect frame = [frameView frame];
		frame.origin.x += offsetLeft;
		frame.origin.y += offsetBottom;
		frame.size.width -= (offsetLeft + offsetRight);
		frame.size.height -= (offsetTop + offsetBottom);
		
		NSPoint p = [theWindow mouseLocationOutsideOfEventStream];
		
		if(NSPointInRect(p, frame))
			return YES;
	}
	
	return YES;
}

- (BOOL)touchesFrame:(id)webFrame inCircleRegion:(NSString*)mouseRegion withRange:(NSRange)range
{
	float offsetTop = 0.0;
	float offsetRight = 0.0;
	float offsetBottom = 0.0;
	float offsetLeft = 0.0;

	NSRange parameterRange;
	parameterRange.location = range.length;
	parameterRange.length = [mouseRegion length] - (range.length + 1);
	NSString* parameterString = [NSString stringWithFormat: @"%@ ", [mouseRegion substringWithRange: parameterRange]];
	
	if(parameterString) {
		NSArray* parameters = [parameterString componentsSeparatedByString: @"px "];
		if(parameters) {
			NSString* top = (NSString*) [parameters objectAtIndex: 0];
			if(top && [top isEqualToString: @"0"] == NO)
				offsetTop = [top floatValue];

			NSString* right = (NSString*) [parameters objectAtIndex: 1];
			if(right && [right isEqualToString: @"0"] == NO)
				offsetRight = [right floatValue];

			NSString* bottom = (NSString*) [parameters objectAtIndex: 2];
			if(bottom && [bottom isEqualToString: @"0"] == NO)
				offsetBottom = [bottom floatValue];

			NSString* left = (NSString*) [parameters objectAtIndex: 3];
			if(left && [left isEqualToString: @"0"] == NO)
				offsetLeft = [left floatValue];
		}
	}
	
	NSView* frameView = [webFrame frameView];
	NSPoint p = [theWindow mouseLocationOutsideOfEventStream];
	
	NSRect frame = [frameView frame];
	frame.origin.x += offsetLeft;
	frame.origin.y += offsetBottom;
	frame.size.width -= (offsetLeft + offsetRight);
	frame.size.height -= (offsetTop + offsetBottom);
		
	float xadj = (frame.size.width * 0.1875);	
		
	{
		NSRect vFrame = frame;
		vFrame.origin.x += xadj;
		vFrame.size.width -= (xadj + xadj);
		
		if(NSPointInRect(p, vFrame))
			return YES;
	}
	
	float yadj = (frame.size.height * 0.1875);	

	{
		NSRect vFrame = frame;
		vFrame.origin.y += yadj;
		vFrame.size.height -= (yadj + yadj);
		
		if(NSPointInRect(p, vFrame))
			return YES;
	}
	
	return NO;
}
/*

- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
}

- (void)webView:(WebView *)sender willPerformDragSourceAction:(WebDragSourceAction)action fromPoint:(NSPoint)point withPasteboard:(NSPasteboard *)pasteboard
{
}*/

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
}

@end


@implementation NSPopUpButton (Amnesty)

- (void)selectTag:(int)tag
{
	if([self respondsToSelector:@selector(selectItemWithTag:)])
	   [self selectItemWithTag:tag];
	else {
		NSArray* items = [self itemArray];
		NSEnumerator* enumerator = [items objectEnumerator];
		NSMenuItem* item;
		
		while(item = [enumerator nextObject]) {
			if([item tag] == tag) {
				[self selectItem:item];
				return;
			}
		}
	}
}

@end
