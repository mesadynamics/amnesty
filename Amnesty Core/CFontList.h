/*
 *  CFontList.h
 *  Amnesty
 *
 *  Created by Danny Espinoza on 5/12/05.
 *  Copyright 2005 Mesa Dynamics, LLC. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

#include <vector>
using std::vector;

class CFontList {
public:
	CFontList();
	virtual ~CFontList();

public:	
	void AddFont(
		FSRefPtr inFont);
		
	void Free();
	
	static CFontList* GetInstance(bool inForceCreate = true) {
		if(sInstance == NULL && inForceCreate)
			return new CFontList;
			
		return sInstance;
	}
	
private:
	vector<ATSFontContainerRef> mList;
	
	static CFontList* sInstance;
};
