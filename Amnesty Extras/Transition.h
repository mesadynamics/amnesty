#import <Cocoa/Cocoa.h>

#define NSRectToCGRect(r) CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height)

@class CIFilter;
@class CIImage;
@class NSAnimation;

typedef enum {
    AnimatingTabViewCopyMachineTransitionStyle = 0,
    AnimatingTabViewDissolveTransitionStyle,
    AnimatingTabViewFlashTransitionStyle,
    AnimatingTabViewModTransitionStyle,
    AnimatingTabViewPageCurlTransitionStyle,
    AnimatingTabViewRippleTransitionStyle,
    AnimatingTabViewSwipeTransitionStyle,
	AnimatingTabViewFlipTransitionStyle,  
	AnimatingTabViewCubeTransitionStyle, 
	AnimatingTabViewZoomDissolveTransitionStyle
} TransitionStyle;

@interface Transition : NSObject {
    int             style;        // the style of transition to use; one of the AnimatingTabViewTransitionStyle values enumerated above
	float			direction;				// +1 = left, -1=right
	
    CIImage			*finalImage;
	CIImage			*initialImage;
	
	NSRect			finalRect;
	NSRect			initialRect;
	NSRect			currentRect;
	
	CIFilter        *transitionFilter;      // the Core Image transition filter that will generate the animation frames
	CIFilter        *transitionFilter2;
	BOOL			chaining;
	NSAnimation		*animation;
	
	id				delegate;
	CIImage         *inputShadingImage;
	
	CIContext*		context;
	
	//debug
	//unsigned int	frames;
}

- (id)initWithDelegate:(id)object;
//- (id)initWithDelegate:(id)object shadingImage:(CIImage*)aInputShadingImage;

- (void)setStyle:(int)aStyle direction:(float)aDirection;
- (void)setInitialView:(NSView*)view;
- (void)setFinalView:(NSView*)view;

// After start is called you'll have to re-load the views again if you want to repeat the animation
- (void)prime;
- (void)start;
- (void)draw;
//- (BOOL)isAnimating;
@end

/*@interface NSObject(TransitionDelegate)
- (void)drawBackground:(NSRect)rect;
@end
*/