//
//  WidgetFlip.h
//  Amnesty
//
//  Created by Danny Espinoza on 2/17/05.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#if defined(FeatureFlip)
#import "Transition.h"

@interface WidgetFlip : NSView {
	NSWindow* widgetWindow;
	NSView* widgetView;
	NSWindowController* widgetController;
	
	Transition* transition;
}

- (void)initAnimationForWindow:(NSWindow*)window andView:(NSView*)view;
- (void)startAnimation:(BOOL)toBack;
- (BOOL)endAnimation;
- (void)runAnimation:(id)sender;

@end

#endif
