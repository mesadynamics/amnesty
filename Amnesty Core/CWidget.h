/*
 *  CWidget.h
 *  Amnesty
 *
 *  Created by Danny Espinoza on Sat Apr 23 2005.
 *  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

#include <Carbon/Carbon.h>

#include <vector>
using std::vector;

class CWidget {	
public:
	CWidget(CFStringRef inPath);
	virtual ~CWidget();
	
	void Core();
	
	void LoadFonts();
	
	CFURLRef GetWidgetURL();

	CFURLRef GetPluginURL();

	CFURLRef GetIconURL();
	
	CFURLRef GetImageURL();
	
	SInt16 GetWidth();
	
	SInt16 GetHeight();
	
	// accessors
	CFStringRef GetPath() {
		return mPath;
	}
	
	bool IsValid() {
		return mValid;
	}
	
	bool IsForbidden() {
		return mForbidden;
	}
	
	void Invalidate() {
		mValid = false;
	}
	
	void Validate() {
		mValid = true;
	}
	
	bool HasPlugin() {
		return (mPlugin == NULL ? false : true);
	}

	id GetController() {
		return mController;
	}
	
	void SetController(id inController) {
		mController = inController;
	}
	
	CFStringRef GetName() {
		return mName;
	}
	
	CFStringRef GetID() {
		return mID;
	}
		
	CFStringRef GetVersion() {
		return mVersion;
	}
		
	bool GetCompatible() {
		return mCompatible;
	}
	
	bool GetSecurityFile() {
		return mSecurityFile;
	}
	
	bool GetSecurityPlugins() {
		return mSecurityPlugins;
	}
	
	bool GetSecurityJava() {
		return mSecurityJava;
	}
	
	bool GetSecurityNet() {
		return mSecurityNet;
	}
	
	bool GetSecuritySystem() {
		return mSecuritySystem;
	}

	NSString* GetLocalFolder() {
		return localFolder;
	}
	
	void SetSerial(int inSet) {
		mSerial = inSet;
	}
	
	int GetSerial() {
		return mSerial;
	}

private:
	void FindLocalFolder();
	
protected:
	CFStringRef mPath;
	CFPropertyListRef mPlist;
	
	bool mValid;
	bool mForbidden;
	bool mFontsLoaded;

private:
	int mSerial;
	id mController;
	NSString* localFolder;

	// owned by mPlist
	CFStringRef mName; 
	CFStringRef mID; 
	CFStringRef mVersion;
	CFStringRef mHTML;
	CFStringRef mPlugin;
	CFNumberRef mWidth;
	CFNumberRef mHeight;
	
	bool mCompatible;
	
	bool mSecurityFile;
	bool mSecurityPlugins;
	bool mSecurityJava;
	bool mSecurityNet;
	bool mSecuritySystem;
};

class CWidgetSorter {
public:
	bool operator() (CWidget* itemOne, CWidget* itemTwo) {
		return (CFStringCompare(itemOne->GetName(), itemTwo->GetName(), kCFCompareCaseInsensitive) == kCFCompareLessThan ? true : false);
	}
};

class CWidgetList {
public:
	CWidgetList();
	virtual ~CWidgetList();

public:	
	void AddWidget(
		CWidget* inWidget);
		
	CWidget* GetByIndex(
		unsigned long inIndex);
		
	CWidget* GetBySerial(
		int inSerial);
		
	CWidget* GetByID(
		CFStringRef inID);
		
	unsigned long Size();
	
	void Sort();
	
	void Free();
	
	static CWidgetList* GetInstance() {
		if(sInstance == NULL)
			return new CWidgetList;
			
		return sInstance;
	}
	
private:
	vector<CWidget*> mList;
	
	int mSerialCounter;
	
	static CWidgetList* sInstance;
};
