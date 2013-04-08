/*
 *  CWidget.cpp
 *  Amnesty
 *
 *  Created by Danny Espinoza on Sat Apr 23 2005.
 *  Copyright (c) 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include "CWidget.h"
#include "CFontList.h"

#include <algorithm>

CWidgetList* CWidgetList::sInstance = NULL;

CWidget::CWidget(
	CFStringRef inPath) :
		mPlist(NULL),
		mFontsLoaded(false),
		mSerial(0)
{
	if(inPath)
		mPath = CFStringCreateCopy(kCFAllocatorDefault, inPath);
		
	mController = nil;
	
	localFolder = nil;
	FindLocalFolder();
	
	mSecurityFile = false;
	mSecurityPlugins = false;
	mSecurityJava = false;
	mSecurityNet = false;
	mSecuritySystem = false;
	
	mCompatible = false;
	
	if(mPath) {
		CFMutableStringRef plistPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
		if(plistPath) {
			CFStringAppend(plistPath, CFSTR("/Info.plist"));
		
			NSString *path = (NSString*) plistPath; // Assume this is a path to a valid plist.
			NSData *plistData;
			NSString *error;
			NSPropertyListFormat format;
			id plist;
			plistData = [NSData dataWithContentsOfFile:path];
			plist = [NSPropertyListSerialization propertyListFromData:plistData
				mutabilityOption:NSPropertyListImmutable
				format:&format
				errorDescription:&error];

			if(!plist) {
				NSLog(@"%@", error);
				[error release];
			}
			else {
				mPlist = (CFPropertyListRef) plist;
				CFRetain(mPlist);
			}
			
			CFRelease(plistPath);
		}
	}
	
	mName = NULL;
	mID = NULL;
	mVersion = NULL;
	mHTML = NULL;
	mPlugin = NULL; // optional
	mWidth = NULL;
	mHeight = NULL;
	
	mValid = false;
	mForbidden = false;

	if(mPlist) {
		CFDictionaryRef dict = (CFDictionaryRef) mPlist;
		
		mName = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("CFBundleDisplayName"));

		if(mName && localFolder) {
			NSString* localPath = [NSString stringWithFormat: @"%@/%@/InfoPlist.strings", (NSString*) mPath, localFolder];
			if(localPath && [[NSFileManager defaultManager] fileExistsAtPath: localPath]) {
				NSString* localName = NULL;
				
				SInt32 macVersion;
				Gestalt(gestaltSystemVersion, &macVersion);
				
				if(macVersion >= 0x1040) {
					NSStringEncoding encoding;
					NSError* error = NULL;
					localName = [NSString stringWithContentsOfFile: localPath usedEncoding: &encoding error: &error];
					
					if(localName == NULL) {
						encoding = NSUTF8StringEncoding;
						localName = [NSString stringWithContentsOfFile: localPath encoding: encoding error: &error];
					}
				}
				else {
					NSData* localData = [NSData dataWithContentsOfFile: localPath];
					if(localData) {
						localName = [[NSString alloc] initWithData: localData encoding: NSUTF8StringEncoding];
						if(localName == NULL)
							localName = [[NSString alloc] initWithData: localData encoding: NSUnicodeStringEncoding];
					}
				}
				
				if(localName) {
					@try {
						NSDictionary* localDictionary = [localName propertyListFromStringsFileFormat];
						if(localDictionary) {
							NSString* localKey = (NSString*) [localDictionary objectForKey: @"CFBundleDisplayName"];
							if(localKey)
								mName = (CFStringRef) localKey;
						}
					}
					
					@catch (NSException* exception) {
						AmnestyLog(@"CWidget exception caught: %@", [exception reason]);
					}
				}
			}
		}
		
	
		if(mName) {
			NSString* noname = [[NSString alloc] initWithUTF8String: "«PROJECTNAME»"];
			NSString* thisname = (NSString*) mName;
			
			if([thisname isEqualToString: noname]) {
				mName = NULL;
			}
			
			[noname release];
		}
		
		if(mName == NULL && mPath) {
			NSArray* widgetComponents = [(NSString*) mPath pathComponents];
			NSString* widgetFolder = (NSString*) [widgetComponents lastObject];
			if(widgetFolder) {
				NSMutableString* widgetName = [NSMutableString stringWithCapacity: 1024];
				[widgetName appendString: widgetFolder];
				
				NSRange range = [widgetName rangeOfString: @".wdgt" options: NSBackwardsSearch];
				if(range.location != NSNotFound) {
					[widgetName replaceCharactersInRange: range withString: @""];
					mName = (CFStringRef) widgetName;
				}
			}
		}
		
		if(mName == NULL)
			mName = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("CFBundleName"));
						
		if(mName)
			CFRetain(mName);
		
		mID = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("CFBundleIdentifier"));
		if(mID)
			CFRetain(mID);
		
		mHTML = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("MainHTML"));
		if(mHTML)
			CFRetain(mHTML);
		
		if(mName && mID && mHTML) {
			mValid = true;
			
			mVersion = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("CFBundleVersion"));
			if(mVersion)
				CFRetain(mVersion);
			
			mPlugin = (CFStringRef) CFDictionaryGetValue(dict, CFSTR("Plugin"));
			if(mPlugin)
				CFRetain(mPlugin);
			
			mWidth = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("Width"));
			if(mWidth) {
				NSString* typeIDString = (NSString*) CFCopyTypeIDDescription(CFGetTypeID(mWidth));
				if([typeIDString isEqualToString: @"CFString"]) { // common widget authoring error
					CFStringRef ns = (CFStringRef) mWidth;
					SInt32 value = CFStringGetIntValue(ns);
					mWidth = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
				}	
				
				if(mWidth) {
					int value = 0;
					if(CFNumberGetValue(mWidth, kCFNumberIntType, &value) && value < 1)
						mWidth = NULL;
					else
						CFRetain(mWidth);
				}
			}
			
			mHeight = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("Height"));
			if(mHeight) {
				NSString* typeIDString = (NSString*) CFCopyTypeIDDescription(CFGetTypeID(mHeight));
				if([typeIDString isEqualToString: @"CFString"]) {  // common widget authoring error
					CFStringRef ns = (CFStringRef) mHeight;
					SInt32 value = CFStringGetIntValue(ns);
					mHeight = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
				}	
				
				if(mHeight) {
					int value = 0;
					if(CFNumberGetValue(mHeight, kCFNumberIntType, &value) && value < 1)
						mHeight = NULL;
					else
						CFRetain(mHeight);
				}
			}

			CFNumberRef compatible = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("BackwardsCompatibleClassLookup"));
			if(compatible) {
				CFNumberGetValue(compatible, kCFNumberCharType, &mCompatible);
				CFRelease(compatible);
			}

			CFNumberRef security = NULL;
			
			bool fullAccess = false;
			security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowFullAccess"));
			if(security) {
				CFNumberGetValue(security, kCFNumberCharType, &fullAccess);
				CFRelease(security);
			}
				
			if(fullAccess) {
				mSecurityFile = true;
				mSecurityPlugins = true;
				mSecurityJava = true;
				mSecurityNet = true;
				mSecuritySystem = true;
			}
			else {
				security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowFileAccessOutsideOfWidget"));
				if(security) {
					CFNumberGetValue(security, kCFNumberCharType, &mSecurityFile);
					CFRelease(security);
				}
				
				security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowInternetPlugins"));
				if(security) {
					CFNumberGetValue(security, kCFNumberCharType, &mSecurityPlugins);
					CFRelease(security);
				}
				
				security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowJava"));
				if(security) {
					CFNumberGetValue(security, kCFNumberCharType, &mSecurityJava);
					CFRelease(security);
				}
				
				security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowNetworkAccess"));
				if(security) {
					CFNumberGetValue(security, kCFNumberCharType, &mSecurityNet);
					CFRelease(security);
				}
				
				security = (CFNumberRef) CFDictionaryGetValue(dict, CFSTR("AllowSystem"));
				if(security) {
					CFNumberGetValue(security, kCFNumberCharType, &mSecuritySystem);
					CFRelease(security);
				}
			}
		}	
	}
	else {
		if(mName == NULL && mPath) {
			mName = CFStringCreateCopy(kCFAllocatorDefault, mPath);

			if(mName)
				CFRetain(mName);
		}		
	}
		
	if(mPlist && (mWidth == NULL || mHeight == NULL)) {
		NSURL* imageURL = (NSURL*) GetImageURL();
		if(imageURL) {
			NSImage* image = [[NSImage alloc] initWithContentsOfURL: imageURL];
			
			if(image) {
				NSSize imageSize = [image size];
				NSImageRep* rep = [[image representations] objectAtIndex: 0];
				float renderedWidth = (rep ? [rep pixelsWide] : imageSize.width);
				float renderedHeight = (rep ? [rep pixelsHigh] : imageSize.height);
				
				if(mWidth == NULL) {
					mWidth = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &renderedWidth);
					if(mWidth)
						CFRetain(mWidth);
				}
						
				if(mHeight == NULL) {
					mHeight = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &renderedHeight);
					if(mHeight)
						CFRetain(mHeight);
				}
						
				[image release];
			}
			
			[imageURL release];
		}
	}
	
	if(mName == NULL) {
		mName = CFStringCreateCopy(kCFAllocatorDefault, CFSTR("???"));
		
		if(mName)
			CFRetain(mName);
	}
}

CWidget::~CWidget()
{
	if(localFolder)
		[localFolder release];
		
	if(mName)
		CFRelease(mName);
	
	if(mID)
		CFRelease(mID);
		
	if(mVersion)
		CFRelease(mVersion);
		
	if(mHTML)
		CFRelease(mHTML);
		
	if(mPlugin)
		CFRelease(mPlugin);
		
	if(mWidth)
		CFRelease(mWidth);
		
	if(mHeight)
		CFRelease(mHeight);
		
	if(mPlist)
		CFRelease(mPlist);
		
	if(mPath)
		CFRelease(mPath);
}

void
CWidget::Core()
{	
	if(mID) {
		NSString* idTest = (NSString*) mID;

		SInt32 macVersion;
		Gestalt(gestaltSystemVersion, &macVersion);
			
		if(macVersion >= 0x1050) {
			if([idTest isEqualToString:@"com.apple.widget.web-clip"]) {
				mValid = false;
				mForbidden = true;
			}	
		}
		else if(macVersion < 0x1040) {
			if([idTest hasPrefix: @"com.apple."]) {
				if(
					[idTest hasSuffix: @".addressbook"] ||
					[idTest hasSuffix: @".calculator"] ||
					[idTest hasSuffix: @".calendar"] ||
					[idTest hasSuffix: @".dictionary"] ||
					[idTest hasSuffix: @".espn"] || // 10.4.4
					[idTest hasSuffix: @".itunes"] ||
					[idTest hasSuffix: @".flighttracker"] ||
					[idTest hasSuffix: @".google"] || // 10.4.4
					[idTest hasSuffix: @".people"] || // 10.4.4
					[idTest hasSuffix: @".phonebook"] ||
					[idTest hasSuffix: @".SkiReport"] || // 10.4.4
					[idTest hasSuffix: @".stickies"] ||
					[idTest hasSuffix: @".stocks"] ||
					[idTest hasSuffix: @".tilegame"] ||
					[idTest hasSuffix: @".translation"] ||
					[idTest hasSuffix: @".unitconverter"] ||
					[idTest hasSuffix: @".weather"] ||
					[idTest hasSuffix: @".worldclock"]
				) {
					mValid = false;
					mForbidden = true;
				}
			}
			
#if defined(BuildScreenSaver)		
			if([idTest isEqualToString: @"com.apple.widget.tvtracker"])
				mValid = false;
				
			if([idTest isEqualToString: @"org.travelwidgets.weatherradio"])
				mValid = false;
#endif
		}
	}
}

void
CWidget::FindLocalFolder()
{
	if(localFolder == nil && mPath) {
		LocaleRef dlr = NULL;
		LocaleRefFromLocaleString("en", &dlr);
		
		NSArray* local = [[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"];
		if(local == nil)
			return;
				
		NSEnumerator* enumerator = [local objectEnumerator];
		NSString* localName;
		while((localName = [enumerator nextObject])) {
			localFolder = [[NSString alloc] initWithFormat: @"%@.lproj", localName];

			NSString* localPath = [NSString stringWithFormat: @"%@/%@", (NSString*) mPath, localFolder];
			BOOL isDir;
			if([[NSFileManager defaultManager] fileExistsAtPath: localPath isDirectory: &isDir] && isDir) {
				return;
			}
			
			[localFolder release];
			localFolder = nil;
							
			if(dlr) {
				LocaleRef lr;
				const char* ls = [localName UTF8String];
				if(ls && LocaleRefFromLocaleString(ls, &lr) == noErr) {
					UniChar displayName[64];
					UniCharCount displayLength = 0;
					if(LocaleGetName(lr, 0, kLocaleNameMask, dlr, 64, &displayLength, displayName) == noErr) {
						NSString* localEnglishName = [NSString stringWithCharacters: displayName length: displayLength];

						localFolder = [[NSString alloc ] initWithFormat: @"%@.lproj", localEnglishName];

						NSString* localPath = [NSString stringWithFormat: @"%@/%@", (NSString*) mPath, localFolder];
						BOOL isDir;
						if([[NSFileManager defaultManager] fileExistsAtPath: localPath isDirectory: &isDir] && isDir) {
							return;
						}
						
						[localFolder release];
						localFolder = nil;
					}	
				}
			}
		}
	}
}

void
CWidget::LoadFonts()
{
	if(mPlist && mPath && mFontsLoaded == false) {
		CFDictionaryRef dict = (CFDictionaryRef) mPlist;
		
		CFArrayRef fonts = (CFArrayRef) CFDictionaryGetValue(dict, CFSTR("Fonts"));
		
		if(fonts) {
			CFRetain(fonts);
			
			for(CFIndex i = 0; i < CFArrayGetCount(fonts); i++) {
				CFStringRef fontName = (CFStringRef) CFArrayGetValueAtIndex(fonts, i);
				if(fontName) {
					CFRetain(fontName);
		
					CFMutableStringRef plistPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
					if(plistPath) {
						CFStringAppend(plistPath, CFSTR("/"));
						CFStringAppend(plistPath, fontName);

						CFURLRef fontURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, plistPath, kCFURLPOSIXPathStyle, false);
						if(fontURL) {
							FSRef ref;
							if(CFURLGetFSRef(fontURL, &ref)) {
                                CFontList* fontList = CFontList::GetInstance();
                                fontList->AddFont(&ref);
							}
							
							CFRelease(fontURL);
						}
							
						CFRelease(plistPath);
					}
					
					CFRelease(fontName);
				}
			}
			
			CFRelease(fonts);
		}
		
		mFontsLoaded = true;
	}
}

CFURLRef
CWidget::GetWidgetURL()
{
	CFURLRef outURL = NULL;
	
	if(mPath && mHTML) {
		CFMutableStringRef plistPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
		if(plistPath) {
			CFStringAppend(plistPath, CFSTR("/"));
			CFStringAppend(plistPath, mHTML);
			
			CFURLRef baseURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, mPath, kCFURLPOSIXPathStyle, true);
			if(baseURL) {
				outURL = CFURLCreateWithFileSystemPathRelativeToBase(kCFAllocatorDefault, plistPath, kCFURLPOSIXPathStyle, false, baseURL);
				CFRelease(baseURL);
			}
			else
				outURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, plistPath, kCFURLPOSIXPathStyle, false);
				
			CFRelease(plistPath);
		}
	}
		
	return outURL;
}

CFURLRef
CWidget::GetPluginURL()
{
	CFURLRef outURL = NULL;
	
	if(mPath && mPlugin) {
		CFMutableStringRef plistPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
		if(plistPath) {
			CFStringAppend(plistPath, CFSTR("/"));
			CFStringAppend(plistPath, mPlugin);

			outURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, plistPath, kCFURLPOSIXPathStyle, false);
				
			CFRelease(plistPath);
		}
	}
	
	return outURL;
}

CFURLRef
CWidget::GetIconURL()
{
	CFURLRef outURL = NULL;
	
	if(mPath) {
		CFMutableStringRef iconPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
		if(iconPath) {
			CFStringAppend(iconPath, CFSTR("/Icon.png"));

			outURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, iconPath, kCFURLPOSIXPathStyle, false);
				
			CFRelease(iconPath);
		}
	}
	
	return outURL;
}

CFURLRef
CWidget::GetImageURL()
{
	CFURLRef outURL = NULL;
	
	if(mPath) {
		CFMutableStringRef iconPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, mPath);
		if(iconPath) {
			CFStringAppend(iconPath, CFSTR("/Default.png"));

			outURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, iconPath, kCFURLPOSIXPathStyle, false);
				
			CFRelease(iconPath);
		}
	}
	
	return outURL;
}

SInt16
CWidget::GetWidth()
{
	SInt16 width = 640;
	
	if(mWidth)
		CFNumberGetValue(mWidth, kCFNumberSInt16Type, &width);
		
	return width;
}

SInt16
CWidget::GetHeight()
{
	SInt16 height = 480;
	
	if(mHeight)
		CFNumberGetValue(mHeight, kCFNumberSInt16Type, &height);
		
	return height;
}

CWidgetList::CWidgetList() :
		mSerialCounter(100)
{
	sInstance = this;
}

CWidgetList::~CWidgetList()
{
	Free();
	
	sInstance = NULL;
}

void
CWidgetList::AddWidget(
	CWidget* inWidget)
{
	if(inWidget) {
		if(inWidget->IsValid() == false) {
			delete inWidget;
			return;
		}
		
		CWidget* widget = GetByID(inWidget->GetID());
		if(widget) {
			delete inWidget;
			return;
		}
		
		inWidget->SetSerial(mSerialCounter++);
		mList.push_back(inWidget);
	}	
}

CWidget*
CWidgetList::GetByIndex(
	unsigned long inIndex)
{
	if(inIndex == 0 || inIndex > mList.size())
		return NULL;
		
	return mList[inIndex - 1];
}

CWidget*
CWidgetList::GetBySerial(
	int inSerial)
{		
	vector<CWidget*>::const_iterator i = mList.begin();
	CWidget* s;
	
	for(i = mList.begin(); i != mList.end(); i++) {
		s = *i;			
		
		if(s->GetSerial() == inSerial)
			return s;
	}
	
	return NULL;
}

CWidget*
CWidgetList::GetByID(
	CFStringRef inID)
{		
	if(inID) {
		vector<CWidget*>::const_iterator i = mList.begin();
		CWidget* s;
		
		for(i = mList.begin(); i != mList.end(); i++) {
			s = *i;			
			
			CFStringRef sID = s->GetID();
			if(sID && CFEqual(sID, inID))
				return s;
		}
	}
	
	return NULL;
}

unsigned long
CWidgetList::Size()
{
	return (unsigned long) mList.size();
}

void
CWidgetList::Sort()
{
	if(mList.size() > 1)
		std::stable_sort(mList.begin(), mList.end(), CWidgetSorter());
}

void
CWidgetList::Free()
{
	vector<CWidget*>::const_iterator i = mList.begin();
	CWidget* s;
	
	for(i = mList.begin(); i != mList.end(); i++) {
		s = *i;			
		delete s;
	}
	
	mList.clear();
}

