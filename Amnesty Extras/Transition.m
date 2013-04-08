//#if defined(FeatureFlip)

#import "Transition.h"

#import <QuartzCore/QuartzCore.h>

#define TRANSITION_DURATION        .5

//#if defined(CoreImageOnly)
// Create a subclass of NSAnimation that we'll use to drive the transition.
@interface NSTransitionAnimation : NSAnimation
@end
//#endif

@implementation Transition

- (id)initWithDelegate:(id)object
{
	if(self = [super init]) {
		delegate = object;
		
		inputShadingImage = nil;
		animation = nil;
		initialImage = nil;
		finalImage = nil;
		transitionFilter = nil;
		transitionFilter2 = nil;
		
		context = nil;
	}
	
	return self;
}

/*- (id)initWithDelegate:(id)object shadingImage:(CIImage*)aInputShadingImage
{
	if(self = [super init]) {
		delegate = object;
		inputShadingImage = [aInputShadingImage retain];
		animation = nil;
		initialImage = nil;
		finalImage = nil;
		transitionFilter = nil;
		transitionFilter2 = nil;
	}
	
	return self;
}*/

// Flush any temporary images and filters
- (void)reset
{
	if(animation) {
		[animation setDelegate:nil];
		[animation release];
	}
	
	if(initialImage)
		[initialImage release];
		
	if(finalImage)	
		[finalImage release];
	
	if(transitionFilter)
		[transitionFilter release];
		
	if(transitionFilter2)
		[transitionFilter2 release];
	
	if(context)
		[context release];
	
	initialImage = nil;
	finalImage = nil;
	transitionFilter = nil;
	transitionFilter2 = nil;
	animation = nil;
	context = nil;
}

- (void)dealloc
{
	[self reset];
	
	if(inputShadingImage)
		[inputShadingImage release];
		
	[super dealloc];
}

- (void)setStyle:(int)aStyle direction:(float)aDirection {
	style = aStyle;
	direction = aDirection;
}

/* Utility:
 * Capture a view into a CoreImage of rect size
 *   I know it's horrible, but at least it is only called twice when starting the transition
 */
- (CIImage *)createCoreImage:(NSView *)view {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSRect rect = [view bounds];
 
	NSBitmapImageRep * bitmap = [view bitmapImageRepForCachingDisplayInRect:rect];
	[view cacheDisplayInRect:rect toBitmapImageRep:bitmap];
	
	//need to place it into an image so we can composite it
	NSImage * image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	
	// Build our offscreen CGContext
	size_t  bytesPerRow = (size_t)rect.size.width *4;			//bytes per row - one byte each for argb
	bytesPerRow += (16 - bytesPerRow%16)%16;		// ensure it is a multiple of 16 - WARNING: artifacts and/or bugs occur if not	
	size_t byteSize = bytesPerRow * (size_t)rect.size.height;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB); 
    void * bitmapData = malloc(byteSize); 
	bzero(bitmapData, byteSize); //only necessary if drawBackground doesn't cover entire image
	
	CGContextRef cg = CGBitmapContextCreate(bitmapData,
		(size_t) rect.size.width,
		(size_t) rect.size.height,
		8, // bits per component
		bytesPerRow,
		colorSpace,
		kCGImageAlphaPremultipliedFirst); //want kCIFormatARGB8 in CIImage
		//http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/chapter_3_section_4.html#//apple_ref/doc/uid/TP30001066-CH203-//apple_ref/doc/uid/TP30001066-CH203-CJBHBFFE
	
	// Ensure the y-axis is flipped
	CGContextTranslateCTM(cg, 0, rect.size.height);	
	CGContextScaleCTM(cg, 1.0, -1.0 );
	
	// Not entirely sure why the pattern is out of phase, but...
	CGContextSetPatternPhase(cg, CGSizeMake(0.0, rect.size.height)); 
	
	// Draw into the offscreen CGContext
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext * nscg = [NSGraphicsContext graphicsContextWithGraphicsPort:cg flipped:NO];
	[NSGraphicsContext setCurrentContext:nscg];
		//[delegate drawBackground:[view frame]];
		//[image compositeToPoint:NSMakePoint([view frame].origin.x, [view frame].origin.y+[view bounds].size.height) operation:NSCompositeSourceOver];
		[image compositeToPoint:NSMakePoint(0.0, rect.size.height) operation:NSCompositeSourceOver];
	[NSGraphicsContext restoreGraphicsState];
	CGContextRelease(cg);

	// Extract the CIImage from the raw bitmap data that was used in the offscreen CGContext
	CIImage * coreimage = [[CIImage alloc] 
		initWithBitmapData:[NSData dataWithBytesNoCopy:bitmapData length:byteSize] 
		bytesPerRow:bytesPerRow 
		size:CGSizeMake(rect.size.width, rect.size.height) 
		format:kCIFormatARGB8
		colorSpace:colorSpace];
	
	// Housekeeping
	[image release];
	CGColorSpaceRelease(colorSpace); 
	//free(bitmapData);
	
	[pool release];
	
	return coreimage;
}

- (void)setInitialView:(NSView*)view {
	initialImage = [self createCoreImage:view];
	initialRect = [view bounds];
	//[initialImage release];
	//initialImage = [image retain];
}

- (void)setFinalView:(NSView*)view {
	finalImage = [self createCoreImage:view];
	finalRect = [view bounds];
	//[finalImage release];
	//finalImage = [image retain];
}

//- (BOOL)isAnimating {
//	return (animation!=nil);
//}

- (void)prime {
	[transitionFilter release];
	[transitionFilter2 release];
	transitionFilter = nil;
	transitionFilter2 = nil;
	chaining = NO;
	
	currentRect = initialRect;

	transitionFilter = [[CIFilter filterWithName:@"CIPerspectiveTransform"] retain];
	[transitionFilter setDefaults];
	[transitionFilter setValue:initialImage forKey:@"inputImage"];

/*	
	switch (style) {
        case AnimatingTabViewCopyMachineTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CICopyMachineTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
            [transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;

       case AnimatingTabViewDissolveTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CIDissolveTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;

        case AnimatingTabViewFlashTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CIFlashTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
            [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
            [transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;

        case AnimatingTabViewModTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CIModTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
            [transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;

        case AnimatingTabViewPageCurlTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CIPageCurlTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[NSNumber numberWithFloat:-M_PI_4] forKey:@"inputAngle"];
            [transitionFilter setValue:initialImage forKey:@"inputBacksideImage"];
            [transitionFilter setValue:inputShadingImage forKey:@"inputShadingImage"];
            [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;

        case AnimatingTabViewSwipeTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CISwipeTransition"] retain];
            [transitionFilter setDefaults];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
			break;

		case AnimatingTabViewFlipTransitionStyle:
			transitionFilter = [[CIFilter filterWithName:@"CIPerspectiveTransform"] retain];
            [transitionFilter setDefaults];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			break;
			
		case AnimatingTabViewCubeTransitionStyle:
			transitionFilter = [[CIFilter filterWithName:@"CIPerspectiveTransform"] retain];
            [transitionFilter setDefaults];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			
			transitionFilter2 = [[CIFilter filterWithName:@"CIPerspectiveTransform"] retain];
            [transitionFilter2 setDefaults];
			[transitionFilter2 setValue:finalImage forKey:@"inputImage"];
			break;
			
		case AnimatingTabViewZoomDissolveTransitionStyle:
			transitionFilter = [[CIFilter filterWithName:@"CIZoomBlur"] retain];
            [transitionFilter setDefaults];
			[transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			
			transitionFilter2 = [[CIFilter filterWithName:@"CIDissolveTransition"] retain];
            [transitionFilter2 setDefaults];
			[transitionFilter2 setValue:finalImage forKey:@"inputTargetImage"];
			chaining = YES;
			break;
			
        case AnimatingTabViewRippleTransitionStyle:
            transitionFilter = [[CIFilter filterWithName:@"CIRippleTransition"] retain];
            [transitionFilter setDefaults];
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:@"inputCenter"];
            [transitionFilter setValue:[CIVector vectorWithX:rect.origin.x Y:rect.origin.y Z:rect.size.width W:rect.size.height] forKey:@"inputExtent"];
            [transitionFilter setValue:inputShadingImage forKey:@"inputShadingImage"];
			[transitionFilter setValue:initialImage forKey:@"inputImage"];
			[transitionFilter setValue:finalImage forKey:@"inputTargetImage"];
            break;		
    }*/
	
	if(transitionFilter!=nil) {
		Class animationClass =  NSClassFromString(@"NSTransitionAnimation");
		if(animationClass) {
			animation = [[animationClass alloc] initWithDuration:TRANSITION_DURATION animationCurve:NSAnimationLinear];
			[animation setDelegate:delegate];
			// Run the animation synchronously.
			
			//frames = 0;
			
			//for(int f = 5; f <= 95; f+=5)
			//	[animation addProgressMark:(float)f/100.0];
			
			[animation setAnimationBlockingMode:NSAnimationNonblocking];
						
			//and then chuck away the images and filters
			//[self reset];
		}
		
		//NSLog(@"%d frames", frames);
	}
}

- (void)start
{
	if(animation)
		[animation startAnimation];
}

/*
 * Utility:
 * Using a CIPerspectiveTransform filter
 *   Render a billboard bounded by (+/- width, +/- height)
 *   At 3D coordinates (px1,pz1, +/- height) (px2,pz2, +/- height) 
 *   On a visual plane at distance dist
 */
+ (void)updatePerspectiveFilter:(CIFilter*)filter
	px1:(float)px1 pz1:(float)pz1 
	px2:(float)px2 pz2:(float)pz2
	dist:(float)dist
	width:(float)width height:(float)height {
	// Convert to coordinates on the visual plane
	float sx1 = dist * px1 / pz1;
	float sy1 = dist * height / pz1;
	float sx2 = dist * px2 / pz2;
	float sy2 = dist * height / pz2;
	[filter setValue:[CIVector vectorWithX:width+sx1 Y:height+sy1] forKey:@"inputTopRight"];
	[filter setValue:[CIVector vectorWithX:width+sx2 Y:height+sy2] forKey:@"inputTopLeft" ];
	[filter setValue:[CIVector vectorWithX:width+sx1 Y:height-sy1] forKey:@"inputBottomRight"];
	[filter setValue:[CIVector vectorWithX:width+sx2 Y:height-sy2] forKey:@"inputBottomLeft"];
}

- (void)draw {
	//frames++;
	
	float time = [animation currentProgress];
	
	BOOL swap = NO;
	if(time>0.5) {
		if(finalImage) {
			currentRect = finalRect;
			
			// Swap images at half-way point
			[transitionFilter setValue:finalImage forKey:@"inputImage"];
			[finalImage release];
			finalImage = nil;	
		}
		
		swap = YES;
	}
	
	NSRect rect = currentRect;

	/*if(style==AnimatingTabViewCubeTransitionStyle) {			
			float vWidth = viewRect.size.width / 2; //damn, we need to compensate for the fact we have a gutter (hence angle2)
		
			float width = rect.size.width / 2;
			float height = rect.size.height / 2;
			float radius = sqrt(width*width+vWidth*vWidth);
			float angle = -direction * M_PI_2 * time + asin(vWidth/radius); 
			float angle2 = -direction * M_PI_2 * time + acos(vWidth/radius)+M_PI_2; 			
			float dist = width * 5; //set a the visual plane a reasonable distance away
		
			// Calculate 3D position (note that we intially lie on the visual plane)
			float px1 = radius * cos(angle);
			float pz1 = dist + vWidth - radius * sin(angle);
			float px2 = radius * cos(angle2);
			float pz2 = dist + vWidth - radius * sin(angle2);
			
			[Transition updatePerspectiveFilter:transitionFilter
				px1:px1 pz1:pz1
				px2:px2 pz2:pz2
				dist:dist
				width:width height:height];
				
			// Now repeat for second face, rotated 90 degrees
			angle += direction*M_PI_2;
			angle2 += direction*M_PI_2;		
			
			px1 = radius * cos(angle);
			pz1 = dist + vWidth - radius * sin(angle);
			px2 = radius * cos(angle2);
			pz2 = dist + vWidth - radius * sin(angle2);
			
			[Transition updatePerspectiveFilter:transitionFilter2
				px1:px1 pz1:pz1
				px2:px2 pz2:pz2
				dist:dist
				width:width height:height];			
			
		} else if(style==AnimatingTabViewFlipTransitionStyle)*/ {		
			float radius = rect.size.width / 2;
			float height = rect.size.height / 2;
			float angle = direction*M_PI * time;
			float dist = radius * 5; //set a the visual plane a reasonable distance away
			
			// Calculate 3D position (note that we intially lie on the visual plane)
			float px1 = radius * cos(angle);
			float pz1 = dist + radius * sin(angle);
			float px2 = -radius * cos(angle);
			float pz2 = dist - radius * sin(angle);
			
			if(swap) {
				//swap the coordinates so we can actually see the other size
				float ss;
				ss = px1; px1 = px2; px2 = ss;
				ss = pz1; pz1 = pz2; pz2 = ss;
			}	
					
			[Transition updatePerspectiveFilter:transitionFilter
				px1:px1 pz1:pz1
				px2:px2 pz2:pz2
				dist:dist
				width:radius height:height];	
						
		} /*else if(style==AnimatingTabViewZoomDissolveTransitionStyle) {
			[transitionFilter setValue:[NSNumber numberWithFloat:(20*time)] forKey:@"inputAmount"];
			[transitionFilter2 setValue:[NSNumber numberWithFloat:time] forKey:@"inputTime"];
			chaining = YES;
		} else {
			//standard transistion
			[transitionFilter setValue:[NSNumber numberWithFloat:time] forKey:@"inputTime"];
		}*/


	// Draw the output, or pass on to second filter
	CIImage * outputCIImage = [transitionFilter valueForKey:@"outputImage"];
	NSRect inputRect = NSMakeRect(0, rect.size.height, rect.size.width, -rect.size.height);
	NSRect outputRect = rect;
	outputRect.origin.x = 32.0;
	outputRect.origin.y = 32.0;
	inputRect = NSInsetRect(inputRect, -32.0, 32.0);
	outputRect = NSInsetRect(outputRect, -32.0, -32.0);

	if(!context) {
		context = [CIContext contextWithCGContext:(CGContextRef)[[NSGraphicsContext currentContext] graphicsPort] options: nil];
		[context retain];
	}
	
	if(context)
		[context drawImage:outputCIImage inRect:NSRectToCGRect(outputRect) fromRect:NSRectToCGRect(inputRect)];
	else
		[outputCIImage drawInRect:outputRect fromRect:inputRect operation:NSCompositeSourceOver fraction:1.0];

#if 0	
	if(chaining) {
		[transitionFilter2 setValue:outputCIImage forKey:@"inputImage"];
	} else {
		[outputCIImage drawInRect:rect fromRect:NSMakeRect(0, rect.size.height, rect.size.width, -rect.size.height) operation:NSCompositeSourceOver fraction:1.0];
	}
		
	/*	
		// They advise this rather than simply [outputCIImage drawInRect... - I can't see any performance difference
		CGRect  cg = CGRectMake(NSMinX(rect), NSMinY(rect),NSWidth(rect), NSHeight(rect));
		if(!context) {
			context = [CIContext contextWithCGContext:[[NSGraphicsContext currentContext] graphicsPort] options: nil];
			[context retain];
		}
		[context drawImage:outputCIImage inRect:cg fromRect:CGRectMake(0, cg.size.height, cg.size.width, -cg.size.height)];
	*/	
			
		
	// Handle the second filter it exists
	if(transitionFilter2) {
		outputCIImage = [transitionFilter2 valueForKey:@"outputImage"];
		[outputCIImage drawInRect:rect fromRect:NSMakeRect(0, rect.size.height, rect.size.width, -rect.size.height) operation:NSCompositeSourceOver fraction:1.0];
	}
#endif	
}
@end

//#if defined(CoreImageOnly)
@implementation NSTransitionAnimation

// Override NSAnimation's -setCurrentProgress: method, and use it as our point to hook in and advance our Core Image transition effect to the next time slice.
- (void)setCurrentProgress:(NSAnimationProgress)progress {
    // First, invoke super's implementation, so that the NSAnimation will remember the proposed progress value and hand it back to us when we ask for it in AnimatingTabView's -drawRect: method.
    [super setCurrentProgress:progress];

    // Now ask the AnimatingTabView (which set itself as our delegate) to display.  Sending a -display message differs from sending -setNeedsDisplay: or -setNeedsDisplayInRect: in that it demands an immediate, syncrhonous redraw of the view.  Most of the time, it's preferrable to send a -setNeedsDisplay... message, which gives AppKit the opportunity to coalesce potentially numerous display requests and update the window efficiently when it's convenient.  But for a syncrhonously executing animation, it's appropriate to use -display.
	[(id)[self delegate] display];
}

@end
//#endif

//#endif