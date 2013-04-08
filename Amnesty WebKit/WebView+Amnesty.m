//
//  WebView+Amnesty.m
//  Amnesty
//
//  Created by Danny Espinoza on 7/28/07.
//  Copyright 2007 Mesa Dynamics, LLC. All rights reserved.
//

#import "WebView+Amnesty.h"


@implementation WebView (Amnesty)

- (BOOL)containsFlash
{
	return [self containsFlashInFrame:[self mainFrame]];
}

- (BOOL)containsFlashInFrame:(WebFrame*)frame
{
	WebDataSource* dataSource = [frame dataSource];
	NSData* data = [dataSource data];
	
	if(data) {
		NSString* dataString = [[[NSString alloc] initWithData:[dataSource data] encoding:NSUTF8StringEncoding] autorelease];	
		
		NSRange flashRange0 = [dataString rangeOfString:@"macromedia.com" options:NSCaseInsensitiveSearch];
		NSRange flashRange1 = [dataString rangeOfString:@"application/x-shockwave-flash" options:NSCaseInsensitiveSearch];
		NSRange flashRange2 = [dataString rangeOfString:@"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" options:NSCaseInsensitiveSearch];
		NSRange flashRange3 = [dataString rangeOfString:@"_IG_EmbedFlash" options:NSCaseInsensitiveSearch];
		
		if(flashRange0.location != NSNotFound || flashRange1.location != NSNotFound || flashRange2.location != NSNotFound || flashRange3.location != NSNotFound)
			return YES;
	}

	NSArray* frames = [frame childFrames];
	NSEnumerator* enumerator = [frames objectEnumerator];
	WebFrame* child;
	
	while((child = [enumerator nextObject])) {
		if([self containsFlashInFrame:child])
			return YES;
	}
	
	return NO;
}

- (FlashIdentifier)containsFlashWithTransparency:(BOOL)trans
{
	return [self containsFlashWithTransparency:trans webFrame:[self mainFrame]];
}

- (FlashIdentifier)containsFlashWithTransparency:(BOOL)trans webFrame:(WebFrame*)frame
{
	FlashIdentifier returnValue = flashNone;
	
	WebDataSource* dataSource = [frame dataSource];
	NSData* data = [dataSource data];
	
	if(data) {
		NSString* dataString = [[[NSString alloc] initWithData:[dataSource data] encoding:NSUTF8StringEncoding] autorelease];	
		
		NSRange flashRange0 = [dataString rangeOfString:@"macromedia.com" options:NSCaseInsensitiveSearch];
		NSRange flashRange1 = [dataString rangeOfString:@"application/x-shockwave-flash" options:NSCaseInsensitiveSearch];
		NSRange flashRange2 = [dataString rangeOfString:@"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" options:NSCaseInsensitiveSearch];
		NSRange flashRange3 = [dataString rangeOfString:@"_IG_EmbedFlash" options:NSCaseInsensitiveSearch];
		
		if(flashRange0.location != NSNotFound || flashRange1.location != NSNotFound || flashRange2.location != NSNotFound || flashRange3.location != NSNotFound) {
			if(trans) {
				NSRange tFlashRange0 = [dataString rangeOfString:@"param name=\"wmode\" value=\"transparent\"" options:NSCaseInsensitiveSearch];
				NSRange tFlashRange1 =[dataString rangeOfString: @"wmode=\"transparent\"" options:NSCaseInsensitiveSearch];
				
				if(tFlashRange0.location != NSNotFound || tFlashRange1.location != NSNotFound)
					return flashTransparent;
				else
					returnValue = flashStandard;
			}
			else
				return flashStandard;
		}
	}

	NSArray* frames = [frame childFrames];
	NSEnumerator* enumerator = [frames objectEnumerator];
	WebFrame* child;
	
	while((child = [enumerator nextObject])) {
		FlashIdentifier childFrameValue = [self containsFlashWithTransparency:trans webFrame:child];
		if(trans) {
			if(childFrameValue == flashTransparent)
				return flashTransparent;
			else if(childFrameValue == flashStandard)
				returnValue = flashStandard;
		}
		else {
			if(childFrameValue != flashNone)
				return childFrameValue;
		}
	}
	
	return returnValue;
}

@end
