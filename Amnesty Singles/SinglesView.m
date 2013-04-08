//
//  SinglesWindow.m
//  Amnesty Singles
//
//  Created by Danny Espinoza on 4/17/06.
//  Copyright 2006 Mesa Dynamics, LLC. All rights reserved.
//

#import "SinglesView.h"
#import "SinglesController.h"

@implementation SinglesView

- (void)awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	
    isDragging = NO;
}

- (void)drawRect:(NSRect)rect
{
    if(isDragging) {
        NSColor* c1 = [NSColor colorWithCalibratedWhite:.80 alpha:1.0];
        NSColor* c2 = [NSColor colorWithCalibratedWhite:.85 alpha:1.0];
        NSGradient* dragGradient = [[NSGradient alloc] initWithStartingColor:c1 endingColor:c2];
        [dragGradient drawInRect:[self frame] angle:90.0];
    }
    else {
        NSColor* c1 = [NSColor colorWithCalibratedWhite:.90 alpha:1.0];
        NSColor* c2 = [NSColor colorWithCalibratedWhite:.95 alpha:1.0];
        NSGradient* normalGradient = [[NSGradient alloc] initWithStartingColor:c1 endingColor:c2];
        [normalGradient drawInRect:[self frame] angle:90.0];
    }
}

- (BOOL)isOpaque
{
	return NO;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSString* fileName = nil;
	NSArray* array = (NSArray*) [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if(array)
		fileName = (NSString*) [array objectAtIndex:0];
	else {
		NSURL* fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
		fileName = [fileURL absoluteString];
	}
		
	if([fileName hasSuffix:@".wdgt"] || [fileName hasSuffix:@".wdgt/"]) {
		isDragging = YES;
		[self setNeedsDisplay:YES];
		
		return NSDragOperationGeneric;
	}
	
   return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	if(isDragging) {
		isDragging = NO;
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if(isDragging) {
		isDragging = NO;
		[self setNeedsDisplay:YES];
	}

	NSURL* fileURL = nil;
	NSString* fileName = nil;
	NSArray* array = (NSArray*) [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if(array)
		fileName = (NSString*) [array objectAtIndex:0];
	else {
		fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
		fileName = [fileURL absoluteString];
	}
	
	if([fileName hasSuffix:@".wdgt"] || [fileName hasSuffix:@".wdgt/"]) {
		SinglesController* parent = (SinglesController*) [[self window] windowController];
		if(fileURL)
			[parent setWidgetFromURL: [[fileURL copy] autorelease]];
		else
			[parent setWidgetFromPath: [[fileName copy] autorelease]];
			
		return YES;
	}
	
	return NO;
}

@end
