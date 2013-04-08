//
//  WidgetMenu.m
//  Amnesty
//
//  Created by Danny Espinoza on 12/6/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetMenu.h"

#import <WebKit/WebKit.h>

@implementation WidgetMenu

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if(aSelector == @selector(addMenuItem:))
		return @"addMenuItem";
		
	if(aSelector == @selector(setMenuItemEnabledAtIndex:isEnabled:))
		return @"setMenuItemEnabledAtIndex";
		
	if(aSelector == @selector(popup:withY:))
		return @"popup";

	// Apple update to undocumented class
	
	if(aSelector == @selector(addSeparatorMenuItem))
		return @"addSeparatorMenuItem";
		
	if(aSelector == @selector(setMenuItemTagAtIndex:tag:))
		return @"setMenuItemTagAtIndex";
		
	if(aSelector == @selector(getMenuItemTagAtIndex:))
		return @"getMenuItemTagAtIndex";
		

	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (NSString *)webScriptNameForKey:(const char *)name
{
	return nil;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return NO;
}

- (id)init
{
	if(self = [super init]) {
		menu = nil;
		window = nil;
	}
	
	return self;
}

- (void)dealloc
{		
	if(menu)
		[menu release];
		
	[super dealloc];
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args
{
	AmnestyLog(@"menu undefined method: %@", name);
	return nil;
}

- (void)setWindow:(NSWindow*)inWindow
{
	window = inWindow;
}

- (void)addMenuItem:(NSString*)menuItemName
{
	if(menu == nil) {
		NSZone* mZone = [NSMenu menuZone];
		menu = [[NSMenu allocWithZone:mZone] initWithTitle: @"WidgetPopup"];
		if(menu)
			[menu setAutoenablesItems: NO];
	}
	
	if(menu)
		[menu addItemWithTitle: menuItemName action:nil keyEquivalent:@""];
}

- (void)setMenuItemEnabledAtIndex:(int)index isEnabled:(BOOL)enabled
{
	if(menu) {
		NSMenuItem* item = [menu itemAtIndex: index];
		if(item)
			[item setEnabled: enabled];
	}
}

- (int)popup:(int)x withY:(int)y
{
	int selectedItem = -1;
	
	if(menu && window) {
		NSRect windowRect = [window frame];
		
		NSRect frameRect;
		frameRect.origin.x = x + 10; // 10 is a kludge for Weather
		frameRect.origin.y = (windowRect.size.height - y) - 20; // 20 is a kludge for Weather
		frameRect.size.width = 128;
		frameRect.size.height = 16;
		
		NSPopUpButton* popup = [[NSPopUpButton alloc] initWithFrame:frameRect pullsDown:NO];
		if(popup) {
			[[window contentView] addSubview: popup];
			[popup setMenu: menu];
			[popup performClick: popup];
			selectedItem = [popup indexOfSelectedItem];
			[popup setHidden:YES];
			[popup release];
		} 
	}
	
	return selectedItem;
}

- (void)addSeparatorMenuItem
{
	if(menu == nil) {
		NSZone* mZone = [NSMenu menuZone];
		menu = [[NSMenu allocWithZone:mZone] initWithTitle: @"WidgetPopup"];
		if(menu)
			[menu setAutoenablesItems: NO];
	}
	
	if(menu)
		[menu addItem: [NSMenuItem separatorItem]];
}

- (void)setMenuItemTagAtIndex:(int)index tag:(int)tag
{
	if(menu) {
		NSMenuItem* item = [menu itemAtIndex:index];
		if(item)
			[item setTag:tag];
	}
}

- (int)getMenuItemTagAtIndex:(int)index
{
	if(menu) {
		NSMenuItem* item = [menu itemAtIndex:index];
		if(item)
			return [item tag];
	}
	
	return 0;
}

@end
