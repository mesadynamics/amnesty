//
//  widgetWindowFlip.m
//  Amnesty
//
//  Created by Danny Espinoza on 2/17/05.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#if defined(FeatureFlip)

#import "AppController.h"
#import "WidgetFlip.h"

@implementation WidgetFlip

- (id)initWithFrame:(NSRect)frame
{
	if(self = [super initWithFrame:frame]) {
		widgetWindow = nil;
		widgetView = nil;		
		transition = nil;
	}
	
	return self;
}

- (void)dealloc
{
	if(transition) {
		[transition release];
		transition = nil;
	}
		
	[super dealloc];
}

- (void)initAnimationForWindow:(NSWindow*)window andView:(NSView*)view
{
	widgetWindow = window;
	widgetView = view;
}

- (void)startAnimation:(BOOL)toBack
{
	if(widgetWindow == nil || widgetView == nil)
		return;

	AppController* ac = (AppController*) [NSApp delegate];
	if([ac doesEnableFlip] == NO)
		return;
		
	// Note: caller MUST disableFlush for self's window and also check for 10.3.9 first
	NSBundle* mainBundle = [NSBundle mainBundle];
	NSBundle* bundle = [NSBundle bundleWithPath: [mainBundle pathForResource:@"Transition" ofType:@"bundle"]];
	if(bundle) {
		Class principalClass = [bundle principalClass];
		if(principalClass) {
			transition = [((Transition*) [principalClass alloc]) initWithDelegate:self];	
			if(transition) {
				widgetController = (id)[widgetWindow delegate];
				[widgetWindow setDelegate:nil];
				
				if(toBack)
					[transition setStyle:AnimatingTabViewFlipTransitionStyle direction:-1.0];	
				else
					[transition setStyle:AnimatingTabViewFlipTransitionStyle direction:+1.0];	
				
				[widgetView setNeedsDisplay:YES];
				[widgetView displayIfNeededIgnoringOpacity];
				[transition setInitialView:widgetView];
			}
		}
	}
}

- (BOOL)endAnimation
{
	if(widgetWindow == nil || widgetView == nil || transition == nil)
		return NO;
	
	[widgetView setNeedsDisplay:YES];
	[widgetView displayIfNeededIgnoringOpacity];
	[transition setFinalView:widgetView];
							
	[self performSelectorOnMainThread: @selector(runAnimation:) withObject: self waitUntilDone:NO];

	return YES;
}

- (void)runAnimation:(id)sender
{	
	[transition prime];

	[[self window] orderFront:self];
		
	[transition start];
	
	[self display];
	[widgetWindow enableFlushWindow];	
	[widgetWindow orderOut:self];
}

- (BOOL)isFlipped
{
	return (transition ? YES : NO);
}

- (BOOL)wantsDefaultClipping
{
	return (transition ? NO : YES);
}

- (void)drawRect:(NSRect)rect
{
	if(transition)
		[transition draw];
}

- (void)animationDidEnd:(NSAnimation*)animation
{
	[transition release];
	transition = nil;
	
	[widgetWindow orderFront:self];
	//[widgetWindow setAlphaValue:1.0];		
	[[self window] orderOut:self];
	[widgetWindow makeKeyWindow];
	
	[[self window] close];
	
	[widgetWindow setDelegate:(id)widgetController];
	
	[widgetView setNeedsDisplay:YES];
}

@end

#endif
