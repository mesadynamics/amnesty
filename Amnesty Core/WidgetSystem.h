//
//  WidgetSystem.h
//  Amnesty
//
//  Created by Danny Espinoza on 5/5/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "WidgetBridge.h"

@interface WidgetSystem : NSObject {
	WidgetBridge* bridge;
	WebScriptObject* scriptObject;
	NSString* shellID;
	NSString* shellPath;
	
	NSMutableArray* gc;
	NSTask* task;
	
	NSFileHandle* inputFile;
	NSFileHandle* outputFile;
	NSFileHandle* errorFile;
				
	NSMutableData* collectedOutput;
	NSMutableData* collectedError;

	BOOL didTerminate;
	NSTimeInterval terminateAt;

	unsigned commandHash;
	
	BOOL didNotify;
	BOOL didWriteToInput;
	BOOL undefinedOutput;
	BOOL undefinedError;
	
	id outputString;
	id errorString;
	int status;
	
	// callbacks
	id onreadoutput;
	id onreaderror;
	id endhandler; // internal (set via system js call)
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args;

- (void)shutdown;
- (void)releaseHandlers;

- (void)setShellID:(id)string;
- (void)setBridge:(id)inBridge;
- (void)setWebScriptObject:(id)object;
- (void)setEndHandler:(id)handler;

- (unsigned)getCommandHash;

- (void)execute:(NSString *)command withPath:(NSString *)path andWait:(BOOL)sync;
- (void)runSync:(id)sender;

- (BOOL)isTerminated;
- (BOOL)readyToRelease;
- (void)releaseTask;

- (void)write:(NSString*)command;
- (void)cancel;
- (void)close;

- (void)errorReceived:(NSNotification *)aNotification;
- (void)outputReceived:(NSNotification *)aNotification;
- (void)checkStatus:(NSNotification *)aNotification;
@end
