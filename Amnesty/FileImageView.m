//
//  FileImageView.m
//  Amnesty
//
//  Created by Danny Espinoza on 6/24/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import "FileImageView.h"


@implementation FileImageView
- (id)init
{
	if(self = [super init]) {
		file = nil;
	}
	
	return self;
}

- (void)dealloc
{
	if(file)
		[file release];
		
	[super dealloc];
}

- (void)setImage:(NSImage *)image
{
	if(image == nil) {
		if(file) {
			[file release];
			file = nil;
		}
	}
		
	[super setImage: image];
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

	if(file) {
		[file release];
		file = nil;
	}

    if ( [[pboard types] containsObject:NSFilenamesPboardType] )
    {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
		NSString* fileString = (NSString*) [files objectAtIndex: 0];
		
		if(fileString)
			file = [[NSString alloc] initWithString: fileString];
    }
		
    return [super performDragOperation: sender];
}

- (NSString*)getFile
{
	return file;
}

- (void)setFile:(NSString*)withFile
{
	if(file) {
		[file release];
		file = nil;
	}
	
	if(withFile)
		file = [[NSString alloc] initWithString: withFile];
}
@end
