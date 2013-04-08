/*
 *  UBusy.cpp
 *  Amnesty
 *
 *  Created by Danny Espinoza on 4/25/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include "UBusy.h"

UBusy* UBusy::sInstance = NULL;
EventLoopTimerUPP UBusy::sTimerUPP = NULL;

NSStatusItem* UBusy::sStatusItem = nil;
NSImage* UBusy::sFlipImage = nil;
NSImage* UBusy::sNormalImage = nil;

void
UBusy::Busy()
{
	if(sInstance == NULL)
		sInstance = new UBusy;

	if(sInstance)
		sInstance->Retain();
}

void
UBusy::NotBusy()
{
	if(sInstance) {
		if(sInstance->Release() == 0) {
			delete sInstance;
			sInstance = NULL;
		}
	}
}

UBusy::UBusy() :
		mReferenceCount(0),
		mFlip(false),
		mTimerRef(NULL)
{
	SInt32 macVersion = 0;
	Gestalt(gestaltSystemVersion, &macVersion);

	if(sStatusItem) {
		if(sTimerUPP == NULL)
			sTimerUPP = NewEventLoopTimerUPP(&TimerCallback);
		
		if(sFlipImage == nil)
			sFlipImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:(macVersion >= 0x1050 ? @"AmnestyLeo2" : @"Amnesty2") ofType:@"png"]];
			
		if(sNormalImage == nil)
			sNormalImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:(macVersion >= 0x1050 ? @"AmnestyLeo" : @"Amnesty") ofType:@"png"]];

		if(!mFlip)
			Flip();

		if(sTimerUPP)	
			InstallEventLoopTimer(GetMainEventLoop(), .3, .3, sTimerUPP, (void*) this, &mTimerRef);
	}
}

UBusy::~UBusy()
{
	if(mTimerRef)
		RemoveEventLoopTimer(mTimerRef);

	if(mFlip)
		Flip();
}

void
UBusy::Flip()
{
	mFlip = !mFlip;
	
	NSImage* image = NULL;
	
	if(mFlip)
		image = sFlipImage;
	else
		image = sNormalImage;

	if(image && sStatusItem)
		[sStatusItem setImage:image];
}

pascal void
UBusy::TimerCallback(
	EventLoopTimerRef inTimerRef,
	void* inUserData)
{
	UBusy* caller = static_cast<UBusy*>(inUserData);
	if(caller)
		caller->Flip();
}

