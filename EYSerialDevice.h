//
//  EYSerialDevice.h
//  OBD2Kit
//
//  Created by Eddie Kelley on 7/28/13.
//
//

#import <Foundation/Foundation.h>

@interface EYSerialDevice : NSObject{
	NSMutableArray*	_modems;
}

@property (retain, nonatomic) NSMutableArray *modems;

@end
