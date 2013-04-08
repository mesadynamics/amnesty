//
//  WidgetView.h
//  Amnesty
//
//  Created by Danny Espinoza on 5/1/05.
//  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <WebKit/WebView.h>

@interface WidgetView : WebView {
	BOOL mouseIn;
	BOOL forceWindow;
	BOOL forceView;
}

@end
