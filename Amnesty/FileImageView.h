//
//  FileImageView.h
//  Amnesty
//
//  Created by Danny Espinoza on 6/24/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

@interface FileImageView : NSImageView {
	NSString* file;
}

- (NSString*)getFile;
- (void)setFile:(NSString*)withFile;

@end
