/*
 *  UBusy.h
 *  Amnesty
 *
 *  Created by Danny Espinoza on 4/25/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

class UBusy {
public:
	static void SetStatusItem(NSStatusItem* inStatusItem) {
		sStatusItem = inStatusItem;
	}
	
	static NSStatusItem* GetStatusItem() {
		return sStatusItem;
	}
	
	static void Busy();
	static void NotBusy();
	
protected:
	UBusy();
	virtual ~UBusy();
	
	inline UInt32 Retain() {
		return ++mReferenceCount;
	}
	
	inline UInt32 Release() {
		return --mReferenceCount;
	}

private:
	void Flip();
	
	static pascal void TimerCallback(
		EventLoopTimerRef inTimerRef,
		void* inUserData);
	
private:
	UInt32 mReferenceCount;
	bool mFlip;
	
	EventLoopTimerRef mTimerRef;
	
	static UBusy* sInstance;
	static EventLoopTimerUPP sTimerUPP;
	
	static NSStatusItem* sStatusItem;
	static NSImage* sFlipImage;
	static NSImage* sNormalImage;
};
