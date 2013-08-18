//
//  EYSerialScanTool.m
//  OBD2Kit
//
//  Created by Eddie Kelley on 7/13/13.
//
//

#import "EYSerialScanTool.h"
#import "NSStreamAdditions.h"
#import "FLLogging.h"

@implementation EYSerialScanTool
@synthesize modemPath;

- (void) dealloc {
	[_inputStream release];
	[_outputStream release];
	[_host release];
	[_cachedWriteData release];
	[super dealloc];
}

- (void) open {
	FLTRACE_ENTRY
	[self dispatchDelegate:@selector(scanDidStart:) withObject:nil];
	@try {
		_inputStream = [NSInputStream inputStreamWithFileAtPath:self.modemPath];
		_outputStream = [NSOutputStream outputStreamToFileAtPath:self.modemPath append:YES];
		
		if((_inputStream != nil) && (_outputStream != nil)) {
			FLDEBUG(@"Streams initialized with path:%@", self.modemPath)
			[_inputStream retain];
			[_inputStream setDelegate:self];
			[_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
			[_inputStream open];
			
			[_outputStream retain];
			[_outputStream setDelegate:self];
			[_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
			[_outputStream open];
			
			if(_inputStream.streamStatus == NSStreamStatusOpen && _outputStream.streamStatus == NSStreamStatusOpen){
				[self dispatchDelegate:@selector(scanToolDidConnect:) withObject:nil];
			}
			else{
				[self dispatchDelegate:@selector(scanToolDidFailToInitialize:) withObject:nil];
			}
			
		}
		else{
			if(!_inputStream){
				if([_inputStream streamError])
					FLNSERROR([_inputStream streamError]);
			}
			else if(!_outputStream){
				if([_outputStream streamError])
					FLNSERROR([_outputStream streamError]);
			}
			[self dispatchDelegate:@selector(scanToolDidFailToInitialize:) withObject:nil];
		}
	}
	@catch (NSException * e) {
		FLEXCEPTION(e);
	}
}


- (void) close {
	FLTRACE_ENTRY
	@try {
		[self closeSession];
	}
	@catch (NSException * e) {
		FLEXCEPTION(e);
	}
	@finally {
		_state = STATE_INIT;
	}
}

- (void) closeSession {
	FLDEBUG(@"-------------------------------------------->>>> CLOSING SERIALSESSION")
	
	[_inputStream close];
    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
									  forMode:NSDefaultRunLoopMode];
    [_inputStream release];
	_inputStream = nil;
    
	[_outputStream close];
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
									   forMode:NSDefaultRunLoopMode];
    [_outputStream release];
	_outputStream = nil;
	
}

- (void) sendCommand:(FLScanToolCommand*)command initCommand:(BOOL)initCommand {
	FLTRACE_ENTRY
	if (!_cachedWriteData) {
        _cachedWriteData = [[NSMutableData alloc] init];
    }
	
	FLDEBUG(@"Writing command to cached data", nil)
    [_cachedWriteData appendData:[command data]];
	[self writeCachedData];
}

- (void) getResponse {
	FLTRACE_ENTRY
	if([_inputStream hasBytesAvailable]) {
		[self stream:_inputStream handleEvent:NSStreamEventHasBytesAvailable];
	}
}

#pragma mark -
#pragma mark Private Methods

- (void) writeCachedData {
    
	FLTRACE_ENTRY
	
	if (_streamOperation.isCancelled) {
		return;
	}
	
	if (!_cachedWriteData) {
		FLERROR(@"No cached data to write (_cachedWriteData == nil)", nil)
		return;
	}
	
	NSOutputStream* oStream			= _outputStream;
	NSStreamStatus oStreamStatus	= NSStreamStatusError;
	NSInteger bytesWritten			= 0;
	
	FLDEBUG(@"[_cachedWriteData length] = %ld", (long)[_cachedWriteData length])
	
    while ([oStream hasSpaceAvailable] &&
		   [_cachedWriteData length] > 0) {
		
		FLDEBUG(@"_cachedWriteData = %@", [_cachedWriteData description])
		
		bytesWritten = [oStream write:[_cachedWriteData bytes]
							maxLength:[_cachedWriteData length]];
		if (bytesWritten == -1) {
			FLERROR(@"Write Error", nil)
			break;
		}
		else if(bytesWritten > 0 && [_cachedWriteData length] > 0) {
			FLDEBUG(@"Wrote %ld bytes", (long)bytesWritten)
			[_cachedWriteData replaceBytesInRange:NSMakeRange(0, bytesWritten)
										withBytes:NULL
										   length:0];
		}
	}
	
	oStreamStatus = [oStream streamStatus];
	FLDEBUG(@"OutputStream status = %X", (unsigned int)oStreamStatus)
	FLDEBUG(@"Starting write wait")
	do {
		oStreamStatus = [oStream streamStatus];
	} while (oStreamStatus == NSStreamStatusWriting);
	
	FLTRACE_EXIT
}

@end
