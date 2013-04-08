//
//  WidgetCalculator.h
//  Amnesty
//
//  Created by Danny Espinoza on 4/30/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface WidgetCalculator : NSObject {
	WebScriptObject* scriptObject;	
}

- (id)invokeUndefinedMethodFromWebScript:(NSString *)name withArguments:(NSArray *)args;

- (void)setWebScriptObject:(id)object;

- (NSString*)evaluateExpression:(NSString*)exp withPrecision:(int)precis;

@end
