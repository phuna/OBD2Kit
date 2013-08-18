//
//  EYSerialScanTool.h
//  OBD2Kit
//
//  Created by Eddie Kelley on 7/13/13.
//
//

#import "FLScanTool.h"

@interface EYSerialScanTool : FLScanTool <NSStreamDelegate> {
	NSInputStream*			_inputStream;
	NSOutputStream*			_outputStream;
	NSMutableData*			_cachedWriteData;
	BOOL					_spaceAvailable;
	NSString*				modemPath;
}

@property (retain, nonatomic) NSString *modemPath;

@end
