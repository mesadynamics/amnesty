//
//  NSTransformApplication.m
//  Rotated Windows
//
//  Created by Wade Tregaskis on Wed May 19 2004.
//
//  Copyright (c) 2004 Wade Tregaskis. All rights reserved.
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//    * Neither the name of Wade Tregaskis nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "WidgetApplication.h"
#import "WidgetWindow.h"
#import "AppController.h"

#if defined(FeatureTransform)
NSRect gMainScreenFrame;
long gTransformCount = 0;

NSPoint
transformNSPoint(
	NSScreen* inScreen,
	NSWindow* inWindow,
	NSPoint inPoint)
{
	CGAffineTransform windowTransform;
	CGPoint tempCG;
	NSPoint tempNS;
	//NSPoint tempNS2;
	NSRect windowFrame, screenFrame;
	
	tempNS = inPoint;//[event locationInWindow];
	//tempNS2 = [event locationInWindow];
	
	//tempCG.x = tempNS.x;
	//tempCG.y = tempNS.y;
	
	// Obtain the transform in use
	CGSGetWindowTransform(_CGSDefaultConnection(), [inWindow windowNumber], &windowTransform);
	
   // Get some necessary information
	windowFrame = [inWindow frame];
	screenFrame = [inScreen frame];
	
	// Translate to screen co-ordinates
	tempCG.x = tempNS.x + windowFrame.origin.x;
	tempCG.y = screenFrame.size.height - (windowFrame.origin.y + tempNS.y);

	// this fixes problems with screens that have different resolutions than the main screen
	tempCG.y -= (screenFrame.size.height -  gMainScreenFrame.size.height);
	
	// Apply the transform
	tempCG = CGPointApplyAffineTransform(tempCG, windowTransform);
	
	//tempNS2 = tempNS; // Debugging
	
	// tempCG is now in inverted window co-ordinates, so we need to invert the y component
	tempNS.x = tempCG.x;
	tempNS.y = (windowFrame.size.height - tempCG.y);
				
	//NSLog(@"%f:%f {%f, %f} -> {%f, %f} gg", screenFrame.size.height, gMainScreenFrame.size.height, tempNS2.x, tempNS2.y, tempNS.x, tempNS.y); // Debugging
	
	//[event setLocationInWindow:tempNS];
	
	return tempNS;
}

void
transformNSEvent(
	NSEvent *event)
{
    if(event) {
		NSEventType et = [event type];
		
		if(
			et == NSKeyDown ||
			et == NSKeyUp ||
			et == NSFlagsChanged ||
			et == NSAppKitDefined ||
			et == NSSystemDefined ||
			et == NSApplicationDefined ||
			et == NSPeriodic ||
			et == NSCursorUpdate
		)
			return;
			
        NSWindow* window = [event window];
				
		if(window == nil)
			window = [NSApp mainWindow];
				
        if(window) {
			if([window respondsToSelector:@selector(transformed)] == NO || [(WidgetWindow*)window transformed] == NO)
				return;
		
 			NSScreen* screen = [window screen]; // dje
			if(screen == nil)
				return;

			if(([event modifierFlags] & (1<<27)) == (1<<27))
				return;
				
			[event setLocationInWindow:transformNSPoint(screen, window, [event locationInWindow])];
       }
    }
}
#endif

#include "UHotKeys.h"


@implementation WidgetApplication

static UInt32 keyCodes[15] = {
	0x7A,
	0x78,
	0x63,
	0x76,
	0x60,
	0x61,
	0x62,
	0x64,
	0x65,
	0x6D,
	0x67,
	0x6F,
	0x69,
	0x6B,
	0x71,
};

- (id)init
{
    if(self = [super init]) {
#if defined(FeatureTransform)
        lastSentEvent = nil;

		gMainScreenFrame = [[NSScreen mainScreen] frame];
#endif

		menuHotKeyRef = NULL;

		CFNumberRef menuKey = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("MenuKey"), CFSTR("com.mesadynamics.Amnesty"));
		int menuIndex = 0;
		if(menuKey && CFNumberGetValue(menuKey, kCFNumberIntType, &menuIndex) && menuIndex) {
			CFNumberRef menuModifiers = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("MenuModifiers"), CFSTR("com.mesadynamics.Amnesty"));
			int modifiers = 0;
			if(menuModifiers)
				CFNumberGetValue(menuModifiers, kCFNumberIntType, &modifiers);
			
			UInt32 keyCode = keyCodes[menuIndex - 1];
			UInt32 keyModifiers = modifiers;
			EventHotKeyID keyID;
			keyID.signature = 'mDaM';
			keyID.id = 1000;
			
			RegisterEventHotKey(keyCode, keyModifiers, keyID, GetApplicationEventTarget(), 0, &menuHotKeyRef); 
		}
		
		toggleHotKeyRef = NULL;

		CFNumberRef toggleKey = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("ToggleKey"), CFSTR("com.mesadynamics.Amnesty"));
		int toggleIndex = 0;
		if(toggleKey && CFNumberGetValue(toggleKey, kCFNumberIntType, &toggleIndex) && toggleIndex) {
			CFNumberRef toggleModifiers = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("ToggleModifiers"), CFSTR("com.mesadynamics.Amnesty"));
			int modifiers = 0;
			if(toggleModifiers)
				CFNumberGetValue(toggleModifiers, kCFNumberIntType, &modifiers);

			UInt32 keyCode = keyCodes[toggleIndex - 1];
			UInt32 keyModifiers = modifiers;
			EventHotKeyID keyID;
			keyID.signature = 'mDaM';
			keyID.id = 1001;
			
			RegisterEventHotKey(keyCode, keyModifiers, keyID, GetApplicationEventTarget(), 0, &toggleHotKeyRef); 
		}
	}
    
    return self;
}

- (void)sendEvent:(NSEvent*)theEvent 
{
	if([theEvent type] == NSSystemDefined && [theEvent subtype] == kEventHotKeyPressedSubtype) {
		EventHotKeyRef ref = (EventHotKeyRef) [theEvent data1];
		
		if(menuHotKeyRef && menuHotKeyRef == ref) {
			AppController* ac = (AppController*) [NSApp delegate];
			[ac dropDownMenu];
		}
		
		if(toggleHotKeyRef && toggleHotKeyRef == ref) {
			AppController* ac = (AppController*) [NSApp delegate];
			[ac toggleWorkspace: self];
		}
		 
		int workspace = UHotKeys::GetWorkspaceFromKey(ref);
		if(workspace) {
			AppController* ac = (AppController*) [NSApp delegate];
			[ac keyWorkspace: workspace];
		}
	}

#if defined(FeatureTransform)
   // NSLog(@"[NSTransformApplication(-) sendEvent:%x]", theEvent);
	
	//if(lastSentEvent != theEvent) {
		transformNSEvent(theEvent);
		//lastSentEvent = theEvent;
	//}
#endif
		
	[super sendEvent:theEvent];
}

#if defined(FeatureTransform)
- (NSEvent *)nextEventMatchingMask:(NSUInteger)mask untilDate:(NSDate *)expiration inMode:(NSString *)mode dequeue:(BOOL)flag
{
    NSEvent* result = [super nextEventMatchingMask:mask untilDate:expiration inMode:mode dequeue:flag];

	if(result) {
		//if(lastSentEvent != result) {
			transformNSEvent(result);
		//	lastSentEvent = result;
		//}
	}
	
	//NSLog(@"[NSTransformApplication(-) nextEventMatchingMask:%d untilDate:... inMode:%@ dequeue:%@] -> %x", mask, mode, (flag ? @"YES" : @"NO"), result);
    
    return result;
}
#endif

@end
