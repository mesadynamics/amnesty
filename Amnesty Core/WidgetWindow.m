#import "WidgetWindow.h"

#import <AppKit/AppKit.h>

#include <ApplicationServices/ApplicationServices.h>

#if defined(FeatureTransform)
extern NSRect gMainScreenFrame;
extern long gTransformCount;
#endif

@implementation WidgetWindow

//In Interface Builder we set CustomWindow to be the class for our window, so our own initializer is called here.
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	isLocked = NO;
	isTransformed = NO;

    //Call NSWindow's version of this function, but pass in the all-important value of NSBorderlessWindowMask
    //for the styleMask so that the window doesn't have a title bar
#if defined(BuildBrowser)
    NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask+NSNonactivatingPanelMask backing:NSBackingStoreBuffered defer:NO];
#else
    NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
#endif
	
	//Set the background color to clear so that (along with the setOpaque call below) we can see through the parts
    //of the window that we're not drawing into
    [result setBackgroundColor: [NSColor clearColor]];
    //This next line pulls the window up to the front on top of other system windows.  This is how the Clock app behaves;
    //generally you wouldn't do this for windows unless you really wanted them to float above everything.
    [result setLevel: NSStatusWindowLevel]; 
	//Let's start with no transparency for all drawing into the window
    [result setAlphaValue:1.0];
    //but let's turn off opaqueness so that we can see through the parts of the window that we're not drawing into
    [result setOpaque:NO];
    //and while we're at it, make sure the window has a shadow, which will automatically be the shape of our custom content.
    [result setHasShadow: NO];
	
	[result setMovableByWindowBackground: (isLocked ? NO : YES)];
	[result setAcceptsMouseMovedEvents: YES];
	//[result useOptimizedDrawing: YES];
    
    return result;
}

- (void)dealloc
{
#if defined(FeatureTransform)
	if(isTransformed)
		gTransformCount--;
#endif
		
	[super dealloc];
}

/*- (void)sendEvent:(NSEvent*)theEvent 
{
	if([theEvent type] == NSLeftMouseUp)
		[theEvent retain];
		
	[super sendEvent:theEvent];
}*/

// Custom windows that use the NSBorderlessWindowMask can't become key by default.  Therefore, controls in such windows
// won't ever be enabled by default.  Thus, we override this method to change that.
- (BOOL)canBecomeKeyWindow
{
	if([self windowController] == nil)
		return NO;

    return YES;
}

- (BOOL)canBecomeMainWindow
{
#if defined(BuildClient)
	return YES;
#else
	if([self windowController] == nil)
		return NO;
			
	return [self isVisible];
#endif
}

- (void)setLocked:(BOOL)set
{
	isLocked = set;
	[self setMovableByWindowBackground: (isLocked ? NO : YES)];
}

- (BOOL)locked
{
	return isLocked;
}

- (BOOL)transformed
{
	return isTransformed;
}

- (void)tweak
{
	[self setMovableByWindowBackground: isLocked];
	[self setMovableByWindowBackground: (isLocked ? NO : YES)];
}

- (void)nudge
{
    NSInteger saveLevel = [self level];
    [self setLevel:NSNormalWindowLevel];
    [self setLevel:saveLevel];
}

#if defined(FeatureTransform)

- (NSPoint)windowToScreenCoordinates:(NSPoint)point {
	//if(isTransformed == NO)
	//	return point;
		
    NSPoint result;
    NSRect screenFrame = [[self screen] frame];
    
    //result = [self convertBaseToScreen:point]; // Doesn't work... it looks like the y co-ordinate is not inverted as necessary
    
	//result.x = screenFrame.origin.x + _frame.origin.x + point.x;
	//result.y = screenFrame.origin.y + screenFrame.size.height - (_frame.origin.y + point.y);

	NSRect windowFrame = [self frame];
	result.x = point.x + windowFrame.origin.x;
	result.y = screenFrame.size.height - (windowFrame.origin.y + point.y);

	// this fixes problems with screens that have different resolutions than the main screen
	result.y -= (screenFrame.size.height -  gMainScreenFrame.size.height);
    	
    return result;
}

- (void)rotate:(double)radians {
    [self rotate:radians about:NSMakePoint(_frame.size.width / 2.0, _frame.size.height / 2.0)];
}

- (void)rotate:(double)radians about:(NSPoint)point {
    CGAffineTransform original;
    NSPoint rotatePoint = [self windowToScreenCoordinates:point];
        
    CGSGetWindowTransform(_CGSDefaultConnection(), _windowNum, &original);
   
    original = CGAffineTransformTranslate(original, rotatePoint.x, rotatePoint.y);
    original = CGAffineTransformRotate(original, -radians);
    original = CGAffineTransformTranslate(original, -rotatePoint.x, -rotatePoint.y);
    
    CGSSetWindowTransform(_CGSDefaultConnection(), _windowNum, original);

	if(isTransformed == NO)
		gTransformCount++;

	isTransformed = YES;
}

- (void)scaleX:(double)x Y:(double)y {
    [self scaleX:x Y:y about:NSMakePoint(_frame.size.width / 2.0, _frame.size.height / 2.0)];
}

- (void)scaleX:(double)x Y:(double)y about:(NSPoint)point {
    CGAffineTransform original;
    NSPoint scalePoint = [self windowToScreenCoordinates:point];
   
    CGSGetWindowTransform(_CGSDefaultConnection(), _windowNum, &original);
    
    original = CGAffineTransformTranslate(original, scalePoint.x, scalePoint.y);
    original = CGAffineTransformScale(original, 1.0 / x, 1.0 / y);
    original = CGAffineTransformTranslate(original, -scalePoint.x, -scalePoint.y);
    
    CGSSetWindowTransform(_CGSDefaultConnection(), _windowNum, original);
	
	if(isTransformed == NO)
		gTransformCount++;
	
	isTransformed = YES;
}

- (void) reset {
	if(isTransformed == NO)
		return;
		
	// Note that this is not quite perfect... if you transform the window enough it may end up anywhere on the screen,
	// but resetting it plonks it back where it started, which may correspond to it's most-logical position at that point in time. 
	// Really what needs to be done is to reset the current transform matrix, in all places except it's translation, such that it stays roughly where it currently is.

	// Get the screen position of the top left corner, by which our window is positioned
	NSPoint point = [self windowToScreenCoordinates:NSMakePoint(0.0, _frame.size.height)];

	CGSSetWindowTransform(_CGSDefaultConnection(), _windowNum, CGAffineTransformMakeTranslation(-point.x, -point.y));
	
	gTransformCount--;
	isTransformed = NO;
}
#endif

//Once the user starts dragging the mouse, we move the window with it. We do this because the window has no title
//bar for the user to drag (so we have to implement dragging ourselves)
- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint currentLocation;
	NSPoint newOrigin;
#if defined(FeatureTransform)
	NSRect screenFrame = gMainScreenFrame;
#else
	NSRect screenFrame = [[NSScreen mainScreen] frame];
#endif	
	NSRect windowFrame = [self frame];

	//grab the current global mouse location; we could just as easily get the mouse location 
	//in the same way as we do in -mouseDown:
	currentLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];

	newOrigin.x = currentLocation.x - initialLocation.x;
	newOrigin.y = currentLocation.y - initialLocation.y;

	// Don't let window get dragged up under the menu bar
	if((newOrigin.y+windowFrame.size.height) > (screenFrame.origin.y+screenFrame.size.height))
		newOrigin.y = screenFrame.origin.y + (screenFrame.size.height-windowFrame.size.height);

	//go ahead and move the window to the new location
	[self setFrameOrigin:newOrigin];
}

//We start tracking the a drag operation here when the user first clicks the mouse,
//to establish the initial location.
- (void)mouseDown:(NSEvent *)theEvent
{    
	NSRect windowFrame = [self frame];

	//grab the mouse location in global coordinates
	initialLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
	initialLocation.x -= windowFrame.origin.x;
	initialLocation.y -= windowFrame.origin.y;
}

- (BOOL)_hasActiveControls
{
	return YES;
}

@end
