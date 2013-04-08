#import <Foundation/Foundation.h>

#include <Carbon/Carbon.h>

#if defined(FeatureTransform)
#import "CoreGraphicsServices.h"
#import "NSEvent+LocationEditing.h"
#endif

enum {
	// NSEvent subtypes for hotkey events (undocumented).
	kEventHotKeyPressedSubtype = 6,
	kEventHotKeyReleasedSubtype = 9,
};

@interface WidgetApplication : NSApplication {
	EventHotKeyRef menuHotKeyRef;
	EventHotKeyRef toggleHotKeyRef;
   
#if defined(FeatureTransform)
	NSEvent* lastSentEvent;
#endif
}

@end
