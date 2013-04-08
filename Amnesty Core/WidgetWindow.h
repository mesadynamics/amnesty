#import <Cocoa/Cocoa.h>

#if defined(FeatureTransform)
#import "CoreGraphicsServices.h"
#endif

@interface WidgetWindow : NSPanel
{
	BOOL isLocked;
	BOOL isTransformed;
    NSPoint initialLocation;
}

- (void)setLocked:(BOOL)set;
- (BOOL)locked;
- (BOOL)transformed;
- (void)tweak;
- (void)nudge;

#if defined(FeatureTransform)
- (NSPoint)windowToScreenCoordinates:(NSPoint)point;
- (void)rotate:(double)radians;
- (void)rotate:(double)radians about:(NSPoint)point;
- (void)scaleX:(double)x Y:(double)y;
- (void)scaleX:(double)x Y:(double)y about:(NSPoint)point;
- (void)reset;
#endif

@end
