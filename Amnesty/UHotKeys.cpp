/*
 *  UHotKeys.cpp
 *  Amnesty
 *
 *  Created by Danny Espinoza on 7/3/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include "UHotKeys.h"

UHotKeys* UHotKeys::sInstance = NULL;
int UHotKeys::sSerialCounter = 10000;

static UInt32 keyCodes[15] = {
	0x7A,
	0x78,
	0x63,
	0x76,
	0x60,
	0x61,
	0x62,
	0x64,
	0x65,
	0x6D,
	0x67,
	0x6F,
	0x69,
	0x6B,
	0x71,
};

void
UHotKeys::AddKey(
	int workspace,
	UInt32 inKey,
	UInt32 inModifiers)
{
	if(sInstance == NULL)
		sInstance = new UHotKeys;
		
	if(sInstance) {
		if(HasKey(inKey, inModifiers))
			return;
		
		EventHotKeyRef ref;
		UInt32 keyCode = keyCodes[inKey - 1];
		UInt32 keyModifiers = inModifiers;
		EventHotKeyID keyID;
		keyID.signature = 'mDaM';
		keyID.id = sInstance->sSerialCounter;
		
		if(RegisterEventHotKey(keyCode, keyModifiers, keyID, GetApplicationEventTarget(), 0, &ref) == noErr) {
			HotKey* key = new HotKey;
			key->workspace = workspace;
			key->key = inKey;
			key->modifiers = inModifiers;
			key->ref = ref;
			
			sInstance->mList.push_back(key);
			
			sInstance->sSerialCounter++;
		}
	}
}

bool
UHotKeys::HasKey(
	UInt32 inKey,
	UInt32 inModifiers)
{
	if(sInstance) {
		vector<HotKey*>::const_iterator i = sInstance->mList.begin();
		HotKey* s;
		
		for(i = sInstance->mList.begin(); i != sInstance->mList.end(); i++) {
			s = *i;			
			
			if(s->key == inKey && s->modifiers == inModifiers)
				return true;
		}
	}
	
	return false;
}

int
UHotKeys::GetWorkspaceFromKey(
	EventHotKeyRef inRef)
{
	if(sInstance) {
		vector<HotKey*>::const_iterator i = sInstance->mList.begin();
		HotKey* s;
		
		for(i = sInstance->mList.begin(); i != sInstance->mList.end(); i++) {
			s = *i;			
			
			if(s->ref == inRef)
				return s->workspace;
		}
	}
	
	return 0;
}

UHotKeys::UHotKeys()
{
}

UHotKeys::~UHotKeys()
{
	Free();
}

void
UHotKeys::Free()
{
	vector<HotKey*>::const_iterator i = sInstance->mList.begin();
	HotKey* s;
		
		for(i = sInstance->mList.begin(); i != sInstance->mList.end(); i++) {
			s = *i;			
		
		if(s->ref)
			UnregisterEventHotKey(s->ref);
						
		delete s;
	}
	
	mList.clear();
}