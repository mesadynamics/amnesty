//
//  WidgetSystem.m
//  Amnesty
//
//  Created by Danny Espinoza on 5/5/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetSystem.h"

unsigned long gShellCount = 1;


@implementation WidgetSystem

- (id)init
{
	if(self = [super init]) {
		bridge = nil;
		scriptObject = nil;
		shellID = nil;
		shellPath = nil;
		
		gc = nil;
		task = nil;
		
		inputFile = nil;
		outputFile = nil;
		errorFile = nil;
				
		collectedOutput = nil;
		collectedError = nil;		
				
		didTerminate = NO;	
		terminateAt = 0.0;
			
		commandHash = 0;

		didNotify = NO;	
		didWriteToInput = NO;		
		undefinedOutput = NO;
		undefinedError = NO;
				
		outputString = nil;
		errorString = nil;
		status = 0;
		
		onreadoutput = nil;
		onreaderror = nil;
		endhandler = nil;
	}
														
	return self;
}

- (void)dealloc
{		
	AmnestyLog(@"system dealloc");
	
	[self shutdown];
	
	[shellID release];

	NSFileManager* fm = [NSFileManager defaultManager];
	if(shellPath && [fm fileExistsAtPath: shellPath]) {
		[fm removeFileAtPath: shellPath handler: nil];
		[shellPath release];
	}
	
	[super dealloc];
}

- (void)shutdown
{
	[self releaseHandlers];
	[self releaseTask];
}

- (void)releaseHandlers
{
	scriptObject = nil;
	
	if(didNotify) {
		NSNotificationCenter* notifier = [NSNotificationCenter defaultCenter];
		[notifier removeObserver:self];

		didNotify = NO;
	}
	
	if(onreadoutput) {
		[onreadoutput release];
		onreadoutput = nil;
	}

	if(onreaderror) {
		[onreaderror release];
		onreaderror = nil;
	}

	if(endhandler) {
		[endhandler release];
		endhandler = nil;
	}
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if(aSelector == @selector(write:))
		return @"write";

	return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return NO;
}

+ (NSString *)webScriptNameForKey:(const char *)name
{
	return nil;
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args
{
	AmnestyLog(@"system undefined method: %@", name);
	return nil;
}

- (void)setShellID:(id)string
{
	shellID = [string retain];
}

- (void)setBridge:(id)inBridge
{
	bridge = inBridge;
}

- (void)setWebScriptObject:(id)object
{
	scriptObject = object;
}

- (void)setEndHandler:(id)handler
{
	endhandler = handler;
	
	if(endhandler)
		[endhandler retain];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	[super setValue:value forKey:key];
	
	if([key isEqualToString:@"onreadoutput"])
		[onreadoutput retain];
	
	if([key isEqualToString:@"onreaderror"])
		[onreaderror retain];
}

- (id)valueForKey:(NSString *)key
{
	//if(scriptObject == nil)
	//	return nil;
		
	if([key isEqualToString:@"outputString"] && outputString == nil) {
		if(collectedOutput) {
			outputString = [[NSString alloc] initWithData:collectedOutput encoding:NSUTF8StringEncoding];
			[gc addObject:outputString];
			[outputString release];
		}
		else if(undefinedOutput) {
			outputString = nil;
			/*outputString = [[NSString alloc] initWithString:@""];
			[gc addObject:outputString];
			[outputString release];*/
		}
	}
	
	if([key isEqualToString:@"errorString"] && errorString == nil) {
		if(collectedError) {
			errorString = [[NSString alloc] initWithData:collectedError encoding:NSUTF8StringEncoding];
			[gc addObject:errorString];
			[errorString release];
		}
		else if(undefinedError) {
			errorString = nil;
			/*errorString = [[NSString alloc] initWithString:@""];
			[gc addObject:errorString];
			[errorString release];*/
		}
	}
	
	AmnestyLog(@"key: %@ value: %@", key, [super valueForKey:key]);
	
	return [super valueForKey:key];
}

- (unsigned)getCommandHash
{
	return commandHash;
}

- (void)execute:(NSString *)command withPath:(NSString *)path andWait:(BOOL)sync
{
	AmnestyLog(@"system %@ executing %@ (%@)", self, (sync ? @"sync" : @"async"), command);
	AmnestyLog(@"system path %@", path);
	
	commandHash = [command hash];
	
	task = [[NSTask alloc] init];
	
	[task setCurrentDirectoryPath: path];		
	
	NSString* tempDir = NSTemporaryDirectory();
	shellPath = nil;
	
	if(shellID == nil)
		shellPath = [[NSString alloc] initWithFormat: @"%@/Amnesty%d.sh", tempDir, (int)gShellCount];
	else
		shellPath = [[NSString alloc] initWithFormat: @"%@/%@.Amnesty%d.sh", tempDir, shellID, (int)gShellCount];
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if([fm fileExistsAtPath: shellPath]) {
		[fm removeFileAtPath: shellPath handler: nil];
	}
	
	NSString* shellString = [NSString stringWithFormat: @"#!/bin/sh\nPATH=\"$PATH:%@\"; export PATH\n\n%@\n\nexit\n", path, command];
	NSData* shellData = [shellString dataUsingEncoding: NSUTF8StringEncoding];
	if(shellData && [fm createFileAtPath: shellPath contents: shellData attributes: nil]) {
		[task setLaunchPath: @"/bin/sh"];
	
		NSArray* arguments = [NSArray arrayWithObject: shellPath];
		[task setArguments: arguments];
	}
	else {
		[task release];
		task = nil;
		
		if(shellString)
			AmnestyLog(@"WidgetSystem:shell script creation failed");
		else
			AmnestyLog(@"WidgetSystem:shell script string creation failed");
			
		return;
	}

	gShellCount++;
	
	gc = [[NSMutableArray alloc] initWithCapacity:0];
	
	NSNotificationCenter* notifier = [NSNotificationCenter defaultCenter];
	didNotify = YES;
	
	NSPipe* errorPipe = [[NSPipe alloc] init];
	[task setStandardError: [NSPipe pipe]];
	[errorPipe release];	
	errorFile = [[task standardError] fileHandleForReading];

	NSPipe* outputPipe = [[NSPipe alloc] init];
	[task setStandardOutput: outputPipe];
	[outputPipe release];	
	outputFile = [[task standardOutput] fileHandleForReading];
	
	if(sync == NO) {
		NSPipe* inputPipe = [[NSPipe alloc] init];
		[task setStandardInput: inputPipe];
		[inputPipe release];

		inputFile = [[task standardInput] fileHandleForWriting];

		[notifier addObserver: self selector: @selector(errorReceived:) name: NSFileHandleDataAvailableNotification object: errorFile];
		[errorFile waitForDataInBackgroundAndNotify];

		[notifier addObserver: self selector: @selector(outputReceived:) name: NSFileHandleDataAvailableNotification object: outputFile];
		[outputFile waitForDataInBackgroundAndNotify];
	}
	
	[notifier addObserver: self selector: @selector(checkStatus:) name: NSTaskDidTerminateNotification object: task];

	@try {
		[task launch];
	}
		
	@catch (NSException* exception) {
		[task release];
		task = nil;
		
		AmnestyLog(@"WidgetSystem:execute exception caught: %@", [exception reason]);
		return;
	}
	
	if(sync)
		[self performSelectorOnMainThread: @selector(runSync:) withObject: self waitUntilDone:YES];
}

- (BOOL)isTerminated
{
	return didTerminate;
}

- (BOOL)readyToRelease
{
	if(didTerminate) {
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		if(now > terminateAt)
			return YES;
	}
	
	return NO;
}

- (void)releaseTask
{
	if(task) {
		AmnestyLog(@"system %@ releasing", self);
			
		NSTask* endTask = task;
		task = nil;

		if([endTask isRunning])
			[endTask terminate];					

		[endTask release];
	}
	
	if(gc) {
		[gc release];
		gc = nil;
	}
}

- (void)write:(NSString*)command
{
	if(task == nil)
		return;
		
	AmnestyLog(@"system %@ writing (%@)", self, command);

	if(inputFile) {	
		NSData* input = [command dataUsingEncoding: NSUTF8StringEncoding];
		if(input) {
			[inputFile writeData: input];
				
			didWriteToInput = YES;
		}
	}
}

- (void)cancel
{
	if(task == nil)
		return;
		
	AmnestyLog(@"system %@ cancelling", self);
		
	if([task isRunning])
		[task terminate];					
}

- (void)close
{
	if(task == nil)
		return;
	
	if(inputFile && didWriteToInput) {
		AmnestyLog(@"system %@ closing", self);

		@try {
			[inputFile closeFile];
		}
		
		@catch (NSException* exception) {
			AmnestyLog(@"WidgetSystem:close exception caught: %@", [exception reason]);
		}
								
		inputFile = nil;
		didWriteToInput = NO;
	}
}

- (void)runSync:(id)sender
{
	NSTimeInterval timer = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval hangTimer = timer + 8.0;
	NSTimeInterval idleTimer = timer + 4.0;
			
	do {
		NSData* outputData = nil;
		BOOL outputFound = NO;
		
		do {
			outputFound = NO;
			
			@try {
				outputData = [outputFile availableData];
			}
			
			@catch (NSException* exception) {
				AmnestyLog(@"WidgetSystem:runSync(output) exception caught: %@", [exception reason]);
				outputData = nil;
			}

			if(outputData && [outputData length]) {
				if(collectedOutput == nil) {
					collectedOutput = [[NSMutableData alloc] initWithLength:0];
					//[gc addObject:collectedOutput];
					//[collectedOutput release];
				}
				
				if(collectedOutput)
					[collectedOutput appendData:outputData];
					
				idleTimer = [NSDate timeIntervalSinceReferenceDate] + 4.0;
				outputFound = YES;
			}
			else if([NSDate timeIntervalSinceReferenceDate] > idleTimer)
				break;
		} while(task && outputFound);
		
		if(collectedOutput)
			break;
		else if([NSDate timeIntervalSinceReferenceDate] > hangTimer)
			break;

	} while(task && [task isRunning]);

	// if there was no ouput, check the error stream
	if(collectedOutput == nil) {
		NSData* errorData = nil;
		BOOL errorFound = NO;
		
		do {
			errorFound = NO;
			
			@try {
				errorData = [errorFile availableData];
			}
			
			@catch (NSException* exception) {
				AmnestyLog(@"WidgetSystem:runSync(error) exception caught: %@", [exception reason]);
				errorData = nil;
			}

			if(errorData && [errorData length]) {
				if(collectedError == nil) {
					collectedError = [[NSMutableData alloc] initWithLength:0];
					//[gc addObject:collectedError];
					//[collectedError release];
				}
					
				if(collectedError)
					[collectedError appendData:errorData];
																	
				idleTimer = [NSDate timeIntervalSinceReferenceDate] + 4.0;
				errorFound = YES;
			}
		} while(task && errorFound);
	}

	if(collectedOutput == nil)
		undefinedOutput = YES;
	else {
		outputString = [[NSString alloc] initWithData:collectedOutput encoding:NSUTF8StringEncoding];
		[gc addObject:outputString];
		[outputString release];
		
		[collectedOutput release];
	}
		
	if(collectedError == nil)
		undefinedError = YES;
	else {
		errorString = [[NSString alloc] initWithData:collectedError encoding:NSUTF8StringEncoding];
		[gc addObject:errorString];
		[errorString release];

		[collectedError release];
	}
		
	if(task && [task isRunning])
		[task terminate];					
}

- (void)errorReceived:(NSNotification *)aNotification
{
	NSData* errorData = [errorFile availableData];
	
	if(errorData && [errorData length]) {
		//NSLog(@"error bytes: %d", [errorData length]);
		
		if(onreaderror && scriptObject) {
			NSString* error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];	
			if(error) {					
				[gc addObject:error];
				[error release];

				NSArray* arguments = [NSArray arrayWithObject: error];
				[scriptObject setValue:onreaderror forKey: @"widget.systemErrorHandler"];
				[scriptObject callWebScriptMethod: @"widget.systemErrorHandler" withArguments: arguments];
			}
			else
				AmnestyLog(@"WidgetSystem:errorReceived encoding problem");
		}

		if(collectedError == nil) {
			collectedError = [[NSMutableData alloc] initWithLength:0];
			[gc addObject:collectedError];
			[collectedError release];
		}
		
		if(collectedError)
			[collectedError appendData:errorData];
			
		[errorFile waitForDataInBackgroundAndNotify];
	}
}

- (void)outputReceived:(NSNotification *)aNotification
{
	NSData* outputData = [outputFile availableData];
	
	if(outputData && [outputData length]) {
		//NSLog(@"output bytes: %d", [outputData length]);
		
		if(onreadoutput && scriptObject) {
			NSString* output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];	
			if(output) {
				[gc addObject:output];
				[output release];
				
				NSArray* arguments = [NSArray arrayWithObject: output];
				[scriptObject setValue:onreadoutput forKey: @"widget.systemOutputHandler"];
				[scriptObject callWebScriptMethod: @"widget.systemOutputHandler" withArguments: arguments];
			}
			else
				AmnestyLog(@"WidgetSystem:outputReceived encoding problem");
		}

		if(collectedOutput == nil) {
			collectedOutput = [[NSMutableData alloc] initWithLength:0];
			[gc addObject:collectedOutput];
			[collectedOutput release];
		}
		
		if(collectedOutput)
			[collectedOutput appendData:outputData];
			
		[outputFile waitForDataInBackgroundAndNotify];
	}
}

- (void)checkStatus:(NSNotification *)aNotification
{
	AmnestyLog(@"system %@ terminating", self);

	status = [[aNotification object] terminationStatus];

	if(endhandler && scriptObject) {
		NSArray* arguments = [NSArray arrayWithObject: self];
		[scriptObject setValue:endhandler forKey: @"widget.systemEndHandler"];
		[scriptObject callWebScriptMethod: @"widget.systemEndHandler" withArguments: arguments];
	}
	
	[self releaseHandlers];
	
	didTerminate = YES;
	terminateAt = [NSDate timeIntervalSinceReferenceDate] + 60.0;

	NSFileManager* fm = [NSFileManager defaultManager];
	if(shellPath && [fm fileExistsAtPath: shellPath]) {
		[fm removeFileAtPath: shellPath handler: nil];
		[shellPath release];
		shellPath = nil;
	}
}
@end
