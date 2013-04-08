//
//  WidgetView.m
//  Amnesty
//
//  Created by Danny Espinoza on 5/1/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetView.h"
#import "WidgetController.h"
#import "WidgetWindow.h"

extern "C" UInt32 GetCurrentKeyModifiers();
extern "C" UInt32 GetCurrentButtonState();


@implementation WidgetView

- (void)awakeFromNib
{
	mouseIn = NO;
	forceWindow = NO;
	forceView = NO;
}

/*- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	[[self window] 
}
 
- (void)mouseEntered:(NSEvent*)theEvent
{
	if(mouseIn == NO) {
#if defined(BuildBrowser)
		NSWindow* modal = [NSApp modalWindow];
		if(modal)
			return;
#endif
					
		[[self window] makeKeyWindow];

		WidgetWindow* window = (WidgetWindow*) [self window];
		if([window locked] == NO) {
			UInt32 modifiers = GetCurrentKeyModifiers();
			if((modifiers & (1<<11))) {
				if(forceWindow == NO) {
					forceWindow = YES;					
					forceView = NO;		
								
					[window tweak];
				}
				
				[[NSCursor openHandCursor] set];
			}
		}
		
		mouseIn = YES;
	}
}

- (void)mouseExited:(NSEvent*)theEvent
{
	mouseIn = NO;
}

- (void)flagsChanged:(NSEvent*)theEvent
{
	NSWindow* modal = [NSApp modalWindow];
	if(modal)
		return;

	WidgetWindow* window = (WidgetWindow*) [self window];
	if([window locked] == YES)
		return;
			
	BOOL didChange = NO;		
	unsigned int modifiers = [theEvent modifierFlags];

	if((modifiers & NSAlternateKeyMask)) {
		if(forceWindow == NO) {
			forceWindow = YES;
			forceView = NO;
			didChange = YES;
			
			[[NSCursor openHandCursor] set];
		}
	}
	else if((modifiers & NSCommandKeyMask)) {
		if(forceView == NO) {
			forceView = YES;
			forceWindow = NO;
			didChange = YES;
			
			[[NSCursor pointingHandCursor] set];
		}
	}
	else {
		if(forceWindow == YES) {
			forceWindow = NO;
			didChange = YES;
			[[NSCursor arrowCursor] set];
		}
		
		if(forceView == YES) {
			forceView = NO;
			didChange = YES;
			[[NSCursor arrowCursor] set];
		}
	}
	
	if(didChange)
		[window tweak];
}
*/

- (NSView*)hitTest:(NSPoint)aPoint
{
	if(forceWindow)
		return self;
		
	//if(GetCurrentButtonState())
	//	return self;
	
	return [super hitTest: aPoint];
}

- (BOOL)mouseDownCanMoveWindow
{
	if(forceWindow)
		return YES;
		
	if(forceView)
		return NO;
		
	WidgetWindow* window = (WidgetWindow*) [self window];
	WidgetController* wc = (WidgetController*) [window windowController];
	if(wc)
		return [wc doesAcceptMouse];
		
	return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return NO;
}

@end
