//
//  WidgetCalculator.m
//  Amnesty
//
//  Created by Danny Espinoza on 4/30/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "WidgetCalculator.h"

@implementation WidgetCalculator

- (id)init
{
	if(self = [super init]) {
		scriptObject = nil;
	}
	
	return self;
}

- (void)dealloc
{		
	[super dealloc];
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	if(aSelector == @selector(evaluateExpression:withPrecision:))
		return @"evaluateExpression";
		
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
	AmnestyLog(@"calculator undefined method: %@", name);
	return nil;
}

- (void)setWebScriptObject:(id)object
{
	scriptObject = object;
}

- (NSString*)evaluateExpression:(NSString*)exp withPrecision:(int)precis
{
	if([exp isEqualToString:@"decimal_string"]) {
		NSNumberFormatter* nf = [[NSNumberFormatter alloc] init];
		return [nf decimalSeparator];

		/*SInt32 macVersion = 0;
		Gestalt(gestaltSystemVersion, &macVersion);

		if(macVersion >= 0x1040) {
			NSNumberFormatter* nf = [[NSNumberFormatter alloc] init];
			return [nf decimalSeparator];
		}
		
		CFLocaleRef locale = CFLocaleCopyCurrent();
		CFNumberFormatterRef numberFormatter = CFNumberFormatterCreate(nil, locale, kCFNumberFormatterDecimalStyle);		
		CFStringRef numberString = (CFStringRef) CFNumberFormatterCopyProperty(numberFormatter, kCFNumberFormatterDecimalSeparator);
		CFRelease(locale);
		
		return (NSString*)numberString;*/
	}
		
	if([exp isEqualToString:@"thousands_separator"]) {
		NSNumberFormatter* nf = [[NSNumberFormatter alloc] init];
		return [nf thousandSeparator];

		/*SInt32 macVersion = 0;
		Gestalt(gestaltSystemVersion, &macVersion);

		if(macVersion >= 0x1040) {
			NSNumberFormatter* nf = [[NSNumberFormatter alloc] init];
			return [nf thousandSeparator];
		}		

		CFLocaleRef locale = CFLocaleCopyCurrent();
		CFNumberFormatterRef numberFormatter = CFNumberFormatterCreate(nil, locale, kCFNumberFormatterDecimalStyle);		
		CFStringRef numberString = (CFStringRef) CFNumberFormatterCopyProperty(numberFormatter, kCFNumberFormatterGroupingSeparator);
		CFRelease(locale);

		return (NSString*)numberString;*/
	}
		
	NSMutableString* eval = [NSMutableString stringWithCapacity: 256];
	[eval appendString: @"eval("];
	[eval appendString: exp];
	[eval appendString: @")"];
	
	NSNumber* number = (NSNumber*) [scriptObject evaluateWebScript: eval];
	NSNumber* intNumber = [NSNumber numberWithInt: [number intValue]];
	if([number isEqualToNumber: intNumber])
		return [NSString stringWithFormat: @"%d", [number intValue]];
	
	return [NSString stringWithFormat: @"%.8g", [number doubleValue]];
}

@end
