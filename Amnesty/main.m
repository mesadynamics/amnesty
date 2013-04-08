//
//  main.m
//  Amnesty
//
//  Created by Danny Espinoza on Sat Apr 23 2005.
//  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "WidgetApplication.h"

int main(int argc, char *argv[])
{
	[WidgetApplication sharedApplication];
	
	return NSApplicationMain(argc,  (const char **) argv);
}
