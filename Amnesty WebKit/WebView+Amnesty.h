//
//  WebView+Amnesty.h
//  Amnesty
//
//  Created by Danny Espinoza on 6/12/07.
//  Copyright 2007 Mesa Dynamics, LLC. All rights reserved.
//

#import <WebKit/WebKit.h>


typedef enum {
	WebDashboardBehaviorAlwaysSendMouseEventsToAllWindows,
	WebDashboardBehaviorAlwaysSendActiveNullEventsToPlugIns,
	WebDashboardBehaviorAlwaysAcceptsFirstMouse,
	WebDashboardBehaviorAllowWheelScrolling
} WebDashboardBehavior;

@interface WebView (ForcePublic)
- (void)setDrawsBackground:(BOOL)flag;
- (BOOL)drawsBackground;

- (void)_setDashboardBehavior:(WebDashboardBehavior)behavior to:(BOOL)flag;
- (BOOL)_dashboardBehavior:(WebDashboardBehavior)behavior;

+ (void)_setShouldUseFontSmoothing:(BOOL)f;
- (void)setProhibitsMainFrameScrolling:(BOOL)prohibits;

- (void)_close;
@end

typedef enum {
	flashNone,
	flashStandard,
	flashTransparent
} FlashIdentifier;

@interface WebView (Amnesty)
- (BOOL)containsFlash;
- (BOOL)containsFlashInFrame:(WebFrame*)frame;

- (FlashIdentifier)containsFlashWithTransparency:(BOOL)trans;
- (FlashIdentifier)containsFlashWithTransparency:(BOOL)trans webFrame:(WebFrame*)frame;
@end
