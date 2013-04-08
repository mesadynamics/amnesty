//
//  Amnesty_Screen_SaverView.m
//  Amnesty Screen Saver
//
//  Created by Danny Espinoza on 8/3/05.
//  Copyright (c) 2005, Mesa Dynamics, LLC. All rights reserved.
//

#import "Amnesty_Screen_SaverView.h"
#import "WebKit/WebKit.h"

#import "WidgetController.h"

#include "CFontList.h"
#include "CWidget.h"
#include "WidgetUtilities.h"

extern "C" UInt32 GetCurrentButtonState();

@implementation Amnesty_Screen_SaverView

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if(self) {
		setup = NO;
		
		opener = nil;
		renderer = nil;
		
		saverFrame = frame;
		
		//blankWindow = nil;
		//setpriority(PRIO_PROCESS, 0, 20);

		theFont = [NSFont fontWithName: @"Lucida Grande" size: 16.0];
		[theFont retain];
		
		theSmallFont = [NSFont fontWithName: @"Lucida Grande" size: 12.0];
		[theSmallFont retain];
		
		theBundle = [NSBundle bundleWithIdentifier: @"com.mesadynamics.AmnestyScreenSaver"];
		[theBundle retain];
		
		theString = [self getAnimatedString: [theBundle localizedStringForKey: @"Greeting" value: @"" table: nil] forFont: theSmallFont withX: 20.0 withY: 20.0];
		[theString retain];
		
		theName = nil;
				
		configureSheet = nil; 
		random = YES;
		animateHyperspace = NO;
		animatePong = NO;
		
		frameCount = -30;
		frameLoopCount = 0;
		
		frameTitle = 150;	
			
		if([self isPreview])
			[self setAnimationTimeInterval: 1.0/30.0];
		else	
			[self setAnimationTimeInterval: 1.0/60.0];

		macVersion = 0;
		Gestalt(gestaltSystemVersion, &macVersion);
		
		webView = nil;
		image = nil;
		
		int rx = SSRandomIntBetween(1, 2);
		if(rx == 2)
			rx = -1;
		
		int ry = SSRandomIntBetween(1, 2);
		if(ry == 2)
			ry = -1;
			
		v.x = (float) rx;
		v.y = (float) ry;
		d.x = 0.0;
		d.y = 0.0;
		
		[self openAmnesty];	
		[self readDefaults];
		
		if([self isPreview] || [self isMainScreen]) {
			if(macVersion >= 0x1039)
				[self startAmnesty];	
		}
		else
			frameCount = frameTitle + 1;
	}
	
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)resetAnimation
{
	[self readDefaults];
	[self startAmnesty];
}

- (void)stopAnimation
{	
	//if(blankWindow)
	//	[blankWindow orderOut: self];

	[self closeAmnesty];
	
	[super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];

	if(webView) {
		if(image == nil) {
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
				image = [[NSImage alloc] init];
				[image addRepresentation:bitmap];
			}
		}
	}

	if(image)
		[image compositeToPoint:r.origin operation:NSCompositeCopy];
	
	if([self isPreview])
		return;
	
	if(frameCount <= frameTitle) {
		if(frameCount < frameTitle) {
			float alpha = (float) (frameTitle - frameCount) / (float) frameTitle;
			[[NSColor colorWithCalibratedRed: 255.0 green: 255.0 blue: 255.0 alpha: alpha] set];
			
			[theString fill];
			[theName fill];
		}
	}
}

- (void)animateOneFrame
{
	NSRect oldFrame = r;
	NSRect newFrame = NSZeroRect;

	BOOL doAnimate = ([self isPreview] || webView ? YES : NO);

	if(doAnimate) {
		NSRect screenFrame = [self frame];
		/*if(!NSEqualRects(screenFrame, saverFrame)) {
			// ugly, but some widgets (like Notepad) resize the window on open
			[[self window] setFrame: saverFrame display: YES ];
			[webView setFrame: SSCenteredRectInRect(screenFrame, saverFrame)];
			return;
		}*/
		
		frameLoopCount++;
	
		if((animateHyperspace || animatePong) && frameLoopCount > frameLoop) {
			frameLoopCount = 0;
			
			newFrame = SSCenteredRectInRect(widgetFrame, screenFrame);
			
			NSRect floatFrame = screenFrame;
			floatFrame.origin.x = 0.0;
			floatFrame.origin.y = 0.0;
			floatFrame.size.width = (screenFrame.size.width - widgetFrame.size.width);
			floatFrame.size.height = (screenFrame.size.height - widgetFrame.size.height);
			floatFrame = SSCenteredRectInRect(floatFrame, screenFrame);
			
			if(animateHyperspace) {
				NSSize zero;
				zero.width = 0.0;
				zero.height = 0.0;
				
				NSPoint offset = SSRandomPointForSizeWithinRect(zero, floatFrame);
				newFrame.origin.x = offset.x - (widgetFrame.size.width * .5);
				newFrame.origin.y = offset.y - (widgetFrame.size.height * .5);
			}
			else if(animatePong) {
				d.x += v.x; 
				d.y += v.y;
				
				newFrame.origin.x += d.x;
				newFrame.origin.y += d.y;
								
				if(newFrame.origin.x >= floatFrame.origin.x + floatFrame.size.width)
					v.x = -v.x;
				else if(newFrame.origin.x < floatFrame.origin.x - widgetFrame.size.width)
					v.x = -v.x;
					
				if(newFrame.origin.y >= floatFrame.origin.y + floatFrame.size.height)
					v.y = -v.y;
				else if(newFrame.origin.y < floatFrame.origin.y - widgetFrame.size.height)
					v.y = -v.y;
			}
			
			r = newFrame;
		}
	}
	
	if([self isPreview])
		[self setNeedsDisplay: YES];
	else {
		[self setNeedsDisplayInRect: oldFrame];
		[self setNeedsDisplayInRect: newFrame];
		
		if(frameCount <= frameTitle) {
			[self setNeedsDisplayInRect: [theString bounds]];
			[self setNeedsDisplayInRect: [theName bounds]];
		}
	}
	
	frameCount++;
}

- (BOOL)hasConfigureSheet
{
	if(macVersion >= 0x1039)
		return YES;
	
    return NO;
}

- (NSWindow*)configureSheet
{
	if(configureSheet == nil) {
		configureSheet = [[ConfigureController alloc] init];
		[configureSheet setSaver:self];
	}
	
	return [configureSheet window];
}

- (void)openAmnesty
{
	// force creation of the application support folder and install sample widgets
	bool installSamples = CreateApplicationSupportFolders();

	if(installSamples && macVersion < 0x1040) {
		NSMutableString* amnestyWidgetString = [NSMutableString stringWithCapacity: 1024];
		[amnestyWidgetString appendString: NSHomeDirectory()];
		[amnestyWidgetString appendString: @"/Library/Application Support/Amnesty/Widgets"];
		[[NSFileManager defaultManager] removeFileAtPath: amnestyWidgetString handler: nil];

		NSMutableString* amnestySampleString = [NSMutableString stringWithCapacity: 1024];
		[amnestySampleString appendString: [theBundle bundlePath]]; 
		[amnestySampleString appendString: @"/Contents/SaverSamples"]; 
		
		[[NSFileManager defaultManager]
			copyPath: amnestySampleString
			toPath: amnestyWidgetString
			handler: nil];
	}

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
	
	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			widget->Core();

			if(widget->IsValid())
				FindPlugins(widget->GetPath(), true);
		}
	}
}

- (void)readDefaults
{
	ScreenSaverDefaults* defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"com.mesadynamics.AmnestyScreenSaver"];

	int animationIndex = [defaults integerForKey: @"Animation"];
	
	NSString* widgetID = [defaults stringForKey: @"Widget"];
	if(widgetID == nil || [widgetID isEqualToString: @""]) {
		if(macVersion < 0x1040)
			widgetID = @"com.neometric.widget.flipclock";
		else
			widgetID = @"com.apple.widget.worldclock";
			
		animationIndex = 1;
	}
	
	switch(animationIndex) {
		case 0:
			animateHyperspace = NO;
			animatePong = NO;
			break;
			
		case 1:
			animateHyperspace = NO;
			animatePong = YES;
			break;
			
		case 2:
			animateHyperspace = YES;
			animatePong = NO;
			break;
	}
	
	if(animateHyperspace)
		frameLoop = 30 * 15;
	else if(animatePong)
		frameLoop = 0;
			
	selected = 1;
	random = YES;

	CWidgetList* list = CWidgetList::GetInstance();	

	for(unsigned long i = 1; i <= list->Size(); i++) {
		CWidget* widget = list->GetByIndex(i);
		if(widget) {
			if(widgetID && [widgetID isEqualToString: (NSString*) widget->GetID()]) {
				selected = i;
				random = NO;
			}
		}
	}
}

- (void)checkForExit:(id)object
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	long holdCount = 0;

	do {
		if([self isAnimating]) {
			if(GetCurrentButtonState()) {	
				if(holdCount++ >= 3) {
					CWidgetList* list = CWidgetList::GetInstance();	

					for(unsigned long i = 1; i <= list->Size(); i++) {
						CWidget* widget = list->GetByIndex(i);
						if(widget) {
							if(widget->IsValid())
								FindPlugins(widget->GetPath(), false);
						}
					}
					
					CFontList* fontList = CFontList::GetInstance();
					fontList->Free();
					
					exit(1);
				}	
			}
			else
				holdCount = 0;
		}
		else
			holdCount = 0;
			
		NSDate* date = [[NSDate alloc] initWithTimeIntervalSinceNow:1.0];	
		[NSThread sleepUntilDate:date];
		[date release];
	} while(1);
	
	[pool release];
}

- (void)startAmnesty
{
	CWidgetList* list = CWidgetList::GetInstance();	

	BOOL bail = YES;
	
	{
		for(unsigned long i = 1; i <= list->Size(); i++) {
			CWidget* widget = list->GetByIndex(i);
			if(widget) {
				if(widget->IsValid())
					bail = NO;
			}
		}
	}

	if(bail)
		return;

	CWidget* widget = list->GetByIndex(selected);
	
	while(random) {
		widget = list->GetByIndex(SSRandomIntBetween(1, list->Size()));
	
		if(widget && widget->IsValid()) 
			break;
	}
	
	if(widget && widget->IsValid()) {
		theName = [self getAnimatedString: (NSString*)widget->GetName() forFont: theFont withX: 0.0 withY: 0.0];
		[theName retain];
	
		NSRect screenFrame = [self frame];
		NSRect nameFrame = [theName bounds];

        NSAffineTransform* os = [NSAffineTransform transform];
        [os translateXBy: (screenFrame.size.width - nameFrame.size.width) * .50  yBy: (screenFrame.size.height * .25) - nameFrame.size.height];
        [theName transformUsingAffineTransform:os];
	
		widgetSerial = widget->GetSerial();
		
		[self openWidget];
	}	
}

- (void)closeAmnesty
{
	CWidgetList* list = CWidgetList::GetInstance();	

	{
		for(unsigned long i = 1; i <= list->Size(); i++) {
			CWidget* widget = list->GetByIndex(i);
			if(widget) {
				if(widget->IsValid())
					FindPlugins(widget->GetPath(), false);

				WidgetController* controller = (WidgetController*) widget->GetController();
				if(controller) {
					[controller setSaver: nil];
					[controller willHide];
					[controller fastClose];
				}
			}
		}
	}

	CFontList* fontList = CFontList::GetInstance();
	fontList->Free();
}

- (void)openWidget
{
	CWidgetList* list = CWidgetList::GetInstance();
	CWidget* widget = list->GetBySerial(widgetSerial);

	if(widget == NULL)
		return;

	if([self isPreview]) {
		NSURL* url = (NSURL*) widget->GetImageURL();
		if(url) {
			if(image)
				[image release];
		
			image = [[NSImage alloc] initWithContentsOfURL: url];

			[image setScalesWhenResized: YES];
			NSSize imageSize = [image size];
			imageSize.width *= .3;
			imageSize.height *= .3;
			[image setSize: imageSize];

			widgetFrame.origin.x = 0;
			widgetFrame.origin.y = 0;
			widgetFrame.size = [image size];
			
			NSRect screenFrame = [self frame];
			r = SSCenteredRectInRect(widgetFrame, screenFrame);
		}
		
		return;
	}

	if(setup == NO) {
		opener = [NSTimer
			scheduledTimerWithTimeInterval: (double) 0.125
			target: self
			selector:@selector(handleOpen:)
			userInfo: nil
			repeats: YES];

		renderer = [NSTimer
			scheduledTimerWithTimeInterval: (double) 1.0
			target: self
			selector:@selector(handleRender:)
			userInfo: nil
			repeats: YES];

		//NSString* owner = [[NSBundle mainBundle] bundleIdentifier];
		[NSThread detachNewThreadSelector: @selector(checkForExit:) toTarget:self withObject:nil];
		
		setup = YES;
	}
	
	widget->LoadFonts();

	WidgetController* controller = [[WidgetController alloc] init];
	
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

	NSString* bid = (NSString*) widget->GetID();
	[controller setWidgetID: bid];
	
	NSString* path = (NSString*) widget->GetPath();
	[controller setWidgetPath: path];
		
	NSWindow* window = [controller window];
	[window setTitle: (NSString*) widget->GetName()];
				
	widgetFrame.origin.x = 0.0;
	widgetFrame.origin.y = 0.0;
	widgetFrame.size.width = (float) widget->GetWidth();
	widgetFrame.size.height = (float) widget->GetHeight();

	NSRect contentRect = [window contentRectForFrameRect: widgetFrame];
	[window setFrame: contentRect display: NO];
	
	[window center];
	
	[controller setSaver: self];
		
	widget->SetController(controller);

	[controller prepareWidget:self];
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
		if([controller busy] == YES) {
			[controller runWidget:self];
			[opener invalidate];
		}	
		else
			[controller loadWidget:self];
	}
}

- (void)handleRender:(id)sender
{
	if(image) {
		[image release];
		image = nil;
	}
}

- (void)handleFront:(id)sender
{
	NSWindow* window = [webView window];
	[window orderOut:self];
}

- (void)animateWidget:(WidgetController*)controller
{
	if(webView == nil) {
		NSWindow* window = [controller window];
		widgetFrame = [window frame];
		
		NSRect screenFrame = [self frame];
		r = SSCenteredRectInRect(widgetFrame, screenFrame);
		[window setFrame:r display:NO];

		webView = [window contentView];
		
		[self performSelectorOnMainThread: @selector(handleFront:) withObject: controller waitUntilDone:NO];
	}
				
#if 0 // obsolete
	if(webView == nil) {
		webView = view;
		
		if(webView) {
			blankWindow = [[NSWindow alloc]
				initWithContentRect: [self frame]
				styleMask: NSBorderlessWindowMask
				backing: NSBackingStoreBuffered
				defer: NO
			];
			[blankWindow setBackgroundColor: [NSColor blackColor]];
			[blankWindow setLevel: NSScreenSaverWindowLevel-1]; 
			[blankWindow setOpaque: YES];
			[blankWindow setHasShadow: NO];
			[blankWindow orderFront: self];

			[webView setHostWindow: [self window]];
			[self addSubview: webView];
			
			NSRect widgetFrame = [webView frame];
			NSRect screenFrame = [self frame];
			/*NSRect newFrame = SSCenteredRectInRect(widgetFrame, screenFrame);
			
			NSRect floatFrame;
			floatFrame.size.width = (screenFrame.size.width - widgetFrame.size.width) - 32.0;
			floatFrame.size.height = (screenFrame.size.height - widgetFrame.size.height) - 32.0;
			floatFrame = SSCenteredRectInRect(floatFrame, screenFrame);
			
			if(animateHyperspace) {
				NSSize zero;
				zero.width = 0.0;
				zero.height = 0.0;
				
				NSPoint offset = SSRandomPointForSizeWithinRect(zero, floatFrame);
				newFrame.origin.x = offset.x - (widgetFrame.size.width * .5);
				newFrame.origin.y = offset.y - (widgetFrame.size.height * .5);

				[webView setFrame: newFrame];
			}
			else*/
				[webView setFrame: SSCenteredRectInRect(widgetFrame, screenFrame)];
		}
	}
#endif
}

- (NSBezierPath *) getAnimatedString: (NSString *) string forFont: (NSFont *) font withX: (float)x withY: (float)y
{
    NSTextView *textview;
    textview = [[NSTextView alloc] init];

    [textview setString: string];
    [textview setFont: font];

    NSLayoutManager *layoutManager;
    layoutManager = [textview layoutManager];

    NSRange range;
    range = [layoutManager glyphRangeForCharacterRange:
                               NSMakeRange (0, [string length])
                           actualCharacterRange: nil];
    NSGlyph *glyphs;
    glyphs = (NSGlyph *) malloc (sizeof(NSGlyph)
                                 * (range.length * 2));
    [layoutManager getGlyphs: glyphs  range: range];

    NSBezierPath *path;
    path = [NSBezierPath bezierPath];

    [path moveToPoint: NSMakePoint (x, y)];
    [path appendBezierPathWithGlyphs: glyphs
          count: range.length  inFont: font];

    free (glyphs);
    [textview release];

    return (path);

} // makePathFromString

- (BOOL) isMainScreen
{
	return NSEqualRects([self frame], [[NSScreen mainScreen] frame]);
}
@end
