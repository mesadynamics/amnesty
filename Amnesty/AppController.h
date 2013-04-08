//
//  AppController.h
//  Amnesty
//
//  Created by Danny Espinoza on Sat Apr 23 2005.
//  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

class CWidget;
@class WidgetController;

@interface AppController : NSObject <NSMenuDelegate> {
	NSStatusItem* statusItem;
	
	IBOutlet NSMenu* theMenu;
	IBOutlet NSWindow* thePreferences;
	IBOutlet NSWindow* theGuide;
	IBOutlet NSImageView* theGuideImage;
	IBOutlet NSWindow* theHints;
	IBOutlet NSWindow* theAbout;

	IBOutlet NSWindow* thePurchase;
	IBOutlet NSWindow* theRegister;

	IBOutlet NSPanel* theWorkspaceName;
	IBOutlet NSTextField* theWorkspaceNameField;
	IBOutlet NSButton* theWorkspaceNameButton;
	
	IBOutlet NSButton* prefSaveStates;
	IBOutlet NSButton* prefSavePositions;
	IBOutlet NSButton* prefSaveSettings;
	IBOutlet NSButton* prefLocalWidgets;
	IBOutlet NSButton* prefSystemWidgets;
	IBOutlet NSButton* prefAmnestyWidgets;

	IBOutlet NSButton* prefLaunchHidden;
	IBOutlet NSButton* prefCloseOnHide;
	IBOutlet NSButton* prefReduceCPU;
	
	IBOutlet NSPopUpButton* prefToggleKey;
	IBOutlet NSButton* prefToggleCommand;
	IBOutlet NSButton* prefToggleControl;
	IBOutlet NSButton* prefToggleOption;
	IBOutlet NSButton* prefToggleShift;
	
	IBOutlet NSPopUpButton* prefDropKey;
	IBOutlet NSButton* prefDropCommand;
	IBOutlet NSButton* prefDropControl;
	IBOutlet NSButton* prefDropOption;
	IBOutlet NSButton* prefDropShift;
	
	IBOutlet NSTextField* prefDropTitle;

	IBOutlet NSPopUpButton* prefSpaceKey;
	IBOutlet NSButton* prefSpaceCommand;
	IBOutlet NSButton* prefSpaceControl;
	IBOutlet NSButton* prefSpaceOption;
	IBOutlet NSButton* prefSpaceShift;
	IBOutlet NSButton* prefSpaceBackground;
	IBOutlet NSColorWell* prefSpaceBackColor;
	IBOutlet NSImageView* prefSpaceImage;
	IBOutlet NSSlider* prefSpaceBackOpacity;
	IBOutlet NSButton* prefSpaceLock;

	IBOutlet NSButtonCell* buyInside;
	IBOutlet NSButtonCell* buyOnline;
	IBOutlet NSButtonCell* buyPayPal;
	IBOutlet NSButtonCell* buyRegister;
	
	IBOutlet NSFormCell* registerName;
	IBOutlet NSFormCell* registerNumber;
	
	NSTimer* opener;
				
	int workspace;
	int savedWorkspace;
	NSMutableArray* theWorkspaces;
	BOOL didSwitchWorkspace;
	
	BOOL doSkipWrite;
	BOOL doSkipOpen;
	BOOL doSkipGuide;
	BOOL didTryPurchase;

	NSMutableArray* theBlotters;
	int blotterWorkspace;
	
	NSMutableArray* theGroups;

	SInt32 macVersion;

	BOOL enableFlip;
	BOOL enableDrop;
	
	BOOL expired;
	int nag;
	NSString *eGenesis;
	//NSString* eAhem;

	// sleep notifications
	io_connect_t root_port;
    io_object_t notifier;
    IONotificationPortRef notifyPortRef;
 }

- (void)awakeFromNib;

- (void)selectWidget:(int)index;
- (void)openWidget:(id)sender;
- (void)handleOpen:(id)sender;
- (void)handleOpenTask:(id)sender;

- (void)menuNeedsUpdate:(NSMenu *)menu;
- (IBAction)menuItemAction: (id)sender;

- (IBAction)checkAction: (id)sender;
- (IBAction)buyAction: (id)sender;
- (IBAction)registerAction: (id)sender;

- (IBAction)openPrefsAction: (id)sender;
- (IBAction)openGuideAction: (id)sender;
- (IBAction)openAboutAction: (id)sender;
- (IBAction)openFolderAction: (id)sender;
- (IBAction)openHintAction: (id)sender;
- (IBAction)cancelHintAction: (id)sender;
- (IBAction)closeHintAction: (id)sender;
- (IBAction)openSettingsAction: (id)sender;
- (IBAction)openFAQs: (id)sender;
- (IBAction)openIssues: (id)sender;
- (IBAction)refreshList: (id)sender;

- (void)buildList;
- (void)buildGroups;

- (IBAction)toggleWorkspace: (id)sender;
- (void)keyWorkspace:(int)index;
- (void)dropDownMenu;

- (void)openBlotters;
- (void)closeBlotters:(BOOL)force;

- (void)switchWorkspace:(int)index;
- (void)buildWorkspaces:(BOOL)bind;
- (void)closeWorkspace;
- (void)openWorkspace;
- (void)writeWorkspace;
- (void)writeWorkspace:(NSString*)com;
- (void)buildWorkspaceHotKeys: (int)usingWorkspace andBind:(BOOL)bind;
- (NSString*)workspaceName;

- (BOOL)useAutoClose;
- (BOOL)canCloseHidden;
- (BOOL)canBringToFront;
- (BOOL)canPutAway;

- (BOOL)doesEnableFlip;
- (BOOL)doesEnableDrop;

- (IBAction)bringToFrontAction: (id)sender;
- (IBAction)putAwayAction: (id)sender;
- (IBAction)saveAsAction: (id)sender;
- (IBAction)saveAsDoneAction: (id)sender;
- (IBAction)saveAsCancelAction: (id)sender;
- (IBAction)deleteAction: (id)sender;
- (IBAction)closeHiddenAction: (id)sender;
- (IBAction)setPrefsAction: (id)sender;
- (IBAction)getMoreAction: (id)sender;

- (void)applicationWillHide:(NSNotification* )aNotification;
- (void)applicationWillUnhide:(NSNotification* )aNotification;
- (void)applicationWillTerminate:(NSNotification* )aNotification;

- (void)buildHotKeys;

- (void)readPreferences;
- (void)writePreferences;

- (void)startModalAndIgnore:(WidgetController*)ignore;
- (void)finishModalAndIgnore:(WidgetController*)ignore;

//- (NSRect)statusItemView;

// sleep notifications
- (void)deregisterForSleepWakeNotification;
- (void)powerMessageReceived:(natural_t)messageType withArgument:(void *) messageArgument;
- (void)registerForSleepWakeNotification;

@end
