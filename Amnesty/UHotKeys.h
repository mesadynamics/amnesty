/*
 *  UHotKeys.h
 *  Amnesty
 *
 *  Created by Danny Espinoza on 7/3/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#include <vector>
using std::vector;

class UHotKeys {
public:
	struct HotKey {
		int workspace;
		UInt32 key;
		UInt32 modifiers;
		EventHotKeyRef ref;
	} Key;
	
	typedef struct HotKey HotKey;
	
public:
	static void AddKey(
		int inWorkspace,
		UInt32 inKey,
		UInt32 inModifiers);
		
	static bool HasKey(
		UInt32 inKey,
		UInt32 inModifiers);
			
	static int GetWorkspaceFromKey(
		EventHotKeyRef inRef);
	
protected:
	UHotKeys();
	virtual ~UHotKeys();
	
	void Free();
	
protected:
	vector<HotKey*> mList;

private:	
	static UHotKeys* sInstance;
	static int sSerialCounter;
};
