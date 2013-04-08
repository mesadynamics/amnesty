//
//  WidgetMenu.h
//  Amnesty
//
//  Created by Danny Espinoza on 12/6/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface WidgetMenu : NSObject {
	NSMenu* menu;
	NSWindow* window;
}

- (id)invokeUndefinedMethodFromWebScript:(NSString*)name withArguments:(NSArray*)args;

- (void)setWindow:(NSWindow*)window;

- (void)addMenuItem:(NSString*)menuItemName;
- (void)setMenuItemEnabledAtIndex:(int)index isEnabled:(BOOL)enabled;
- (int)popup:(int)x withY:(int)y;

- (void)addSeparatorMenuItem;
- (void)setMenuItemTagAtIndex:(int)index tag:(int)tag;
- (int)getMenuItemTagAtIndex:(int)index;
@end
