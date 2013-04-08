/*
 *  CFontList.cpp
 *  Amnesty
 *
 *  Created by Danny Espinoza on 5/12/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */ 

#include "CFontList.h"

CFontList* CFontList::sInstance = NULL;

CFontList::CFontList()
{
	sInstance = this;
}

CFontList::~CFontList()
{
	Free();
	
	sInstance = NULL;
}

void
CFontList::AddFont(
	FSRefPtr inFont)
{
	if(inFont) {
		ATSFontContainerRef s;

		if(ATSFontActivateFromFileReference(
			inFont,
			kATSFontContextLocal,
			kATSFontFormatUnspecified,
			NULL,
			kATSOptionFlagsDefault,
			&s) == noErr
		)
			mList.push_back(s);
	}
}

void
CFontList::Free()
{
	bool didChangeFonts = false;
	
	vector<ATSFontContainerRef>::const_iterator i = mList.begin();
	ATSFontContainerRef s;
	
	for(i = mList.begin(); i != mList.end(); i++) {
		s = *i;			
		ATSFontDeactivate(s, NULL, kATSOptionFlagsDoNotNotify);
		didChangeFonts = true;
	}
	
	mList.clear();

	if(didChangeFonts)
		ATSFontNotify(kATSFontNotifyActionFontsChanged, NULL);
}

