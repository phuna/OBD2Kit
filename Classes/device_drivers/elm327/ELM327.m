/*
 *  ELM327.m
 *  OBD2Kit
 *
 *  Copyright (c) 2009-2011 FuzzyLuke Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "ELM327.h"
#import "ELM327Command.h"
#import "ELM327ResponseParser.h"
#import "FLLogging.h"

@interface ELM327 (Private)
- (FLScanToolCommand*) commandForInitState:(ELM327InitState)state;
- (void) handleInputEvent:(NSStreamEvent)eventCode;
- (void) handleOutputEvent:(NSStreamEvent)eventCode;
- (void) readInput;
- (void) readInitResponse;
- (void) readVoltageResponse;
@end


#pragma mark -
@implementation ELM327

@synthesize initState	= _initState;


- (id) init {
	if (self = [super init]) {
		_deviceType		= kScanToolDeviceTypeELM327;
		_deadmanTimer = nil;
	}
	
	return self;
}

- (NSString*) scanToolName {
	return @"ELM327";
}

- (void) startInitTimer{
	if (_deadmanTimer != nil) {
		[_deadmanTimer invalidate];
		_deadmanTimer = nil;
	}
	_deadmanTimer = [NSTimer scheduledTimerWithTimeInterval:INIT_TIMEOUT target:self selector:@selector(initTimerExpired) userInfo:nil repeats:NO];
	FLINFO(@"STARTED INIT TIMER")
}

- (void) initTimerExpired{
	FLTRACE_ENTRY
	[self dispatchDelegate:@selector(scanTool:didTimeoutOnCommand:) withObject:nil];
	[_deadmanTimer invalidate];
}

- (void) invalidateInitTimer{
	// kill deadman timer
	if(_deadmanTimer != nil){
		if([_deadmanTimer respondsToSelector:@selector(invalidate)]){
			FLINFO(@"STOPPED INIT TIMER")
			[_deadmanTimer invalidate];
		}
	}
}

#pragma mark -
#pragma mark ScanTool Initialization

- (FLScanToolCommand*) commandForInitState:(ELM327InitState)state {
	
	FLScanToolCommand* cmd = nil;
	
	switch (state) {
		case ELM327_INIT_STATE_RESET:
			cmd = (FLScanToolCommand*)[ELM327Command commandForReset];
			break;

		case ELM327_INIT_STATE_ECHO_OFF:
			cmd = (FLScanToolCommand*)[ELM327Command commandForEchoOff];
			break;
			
		case ELM327_INIT_STATE_PROTOCOL:
			cmd = (FLScanToolCommand*)[ELM327Command commandForReadProtocol];
			break;
		
		case ELM327_INIT_STATE_VERSION:
			cmd = (FLScanToolCommand*)[ELM327Command commandForReadVersionID];
			break;
			
		case ELM327_INIT_STATE_PID_SEARCH:
			cmd = (FLScanToolCommand*)[ELM327Command commandForOBD2:kScanToolModeRequestCurrentPowertrainDiagnosticData 
															  pid:_currentPIDGroup 
															 data:nil];
			break;
		case ELM327_INIT_STATE_CODES:
			cmd = (FLScanToolCommand*)[ELM327Command commandForOBD2:kScanToolModeRequestEmissionRelatedDiagnosticTroubleCodes
																pid:-1
															   data:nil];
			break;
		case ELM327_INIT_STATE_CODES_PENDING:
			cmd = (FLScanToolCommand*)[ELM327Command commandForOBD2:kScanToolModeRequestEmissionRelatedDiagnosticTroubleCodesDetected
																pid:-1
															   data:nil];
			break;
		case ELM327_INIT_STATE_UNKNOWN:
		default:
			break;
	}			
	
	return cmd;
}

- (void) initScanTool {
	
	FLTRACE_ENTRY
	
	FLINFO(@"Initializing ELM327")
	
	@try {
		
		CLEAR_READBUF()
		_state				= STATE_INIT;
		_initState			= ELM327_INIT_STATE_RESET;
		_currentPIDGroup	= 0x00;
		
		FLDEBUG(@"_inputStream status = %08X", (unsigned int)[_inputStream streamStatus])
		FLDEBUG(@"_outputStream status = %08X", (unsigned int)[_outputStream streamStatus])
		
		if ([_inputStream streamStatus] == NSStreamStatusError) {
			FLNSERROR([_inputStream streamError])
			[self cancelScan];
			//[self dispatchDelegate:@selector(scanToolDidFailToInitialize:) withObject:nil];

		}
		else if([_outputStream streamStatus] == NSStreamStatusError){
			FLNSERROR([_outputStream streamError])
			[self cancelScan];
			//[self dispatchDelegate:@selector(scanToolDidFailToInitialize:) withObject:nil];
		}
		else{
			[self startInitTimer];
			
			while ([_inputStream streamStatus] != NSStreamStatusOpen &&
				   [_outputStream streamStatus] != NSStreamStatusOpen) {
				;
			}

			FLINFO(@"Resetting connection")
			[self sendCommand:(FLScanToolCommand*)[ELM327Command commandForReset] initCommand:YES];
		}
	}
	@catch (NSException * e) {
		FLEXCEPTION(e)
		[self dispatchDelegate:@selector(scanToolDidFailToInitialize:) withObject:nil];
	}
	@finally {
		;
	}
}

- (void) readInitResponse {
	FLTRACE_ENTRY
	
	@try {
		NSInteger readLength = [_inputStream read:&_readBuf[_readBufLength] maxLength:(sizeof(_readBuf) - (_readBufLength-1))];
		FLDEBUG(@"Read %ld bytes", (long)readLength)
		FLDEBUG(@"_readBufLength = %ld", (long)_readBufLength)
		
		if(readLength > 0) {
			
			_readBufLength += readLength;		
			
			if(ELM_READ_COMPLETE(_readBuf, (_readBufLength-1))) {
				
				_readBuf[(_readBufLength - 3)] = 0x00;
				_readBufLength			-= 3;
				
				char* asciistr			= (char*)_readBuf;
				FLDEBUG(@"Data Returned: %s", asciistr)
				
				NSString* respString	= [NSString stringWithCString:(const char*)_readBuf encoding:NSASCIIStringEncoding];
				
				if(ELM_ERROR(asciistr)) {
					FLERROR(@"Error response from ELM327 (state=%d): %@", _initState, respString);
					_initState	= ELM327_INIT_STATE_RESET;
					_state		= STATE_INIT;
				}
				else {
					FLDEBUG(@"ELM327_INIT_STATE: %d", _initState)
					switch(_initState) {
						case ELM327_INIT_STATE_RESET:
							if(0) {
								FLERROR(@"Error response from ELM327 during Reset: %@", respString);
							}
							else {
								_initState <<= 1;
							}
							break;
							
						case ELM327_INIT_STATE_ECHO_OFF:
							if(ELM_ECHO_OFF_OK(asciistr) || ELM_ECHO_OFF_OK_1(asciistr)) {
								FLINFO(@"Echo off");
								_initState <<= 1;
							}
							else {
								FLERROR(@"Error response from ELM327 during Echo Off: \"%s\"", MyLogString(asciistr))
							}
							break;
							
						case ELM327_INIT_STATE_PROTOCOL:
							if(*asciistr == 'A') {
								// The 'A' is for Automatic.  The actual
								// protocol number is at location 1, so
								// increment pointer by 1
								asciistr++;
							}
							
							_protocol = GET_PROTOCOL(((int)*asciistr) - 0x30);
							
							if(_protocol != kScanToolProtocolNone) {
								_initState <<= 1;
							}
							
							break;
							
						case ELM327_INIT_STATE_VERSION:
							_initState <<= 1;
							break;
							
						case ELM327_INIT_STATE_PID_SEARCH:	{							
						
							if(ELM_ERROR(asciistr)) {
								FLERROR(@"Error response from ELM327 during PID search (state=%d): %@", _initState, respString)
								_initState = ELM327_INIT_STATE_RESET;
							}
							else if(CAN_ERROR(asciistr)){
								FLERROR(@"Error response from ELM327 during PID search (state=%d): %@", _initState, respString)
								_initState = ELM327_INIT_STATE_RESET;
							}
							else {							
								if(!_parser) {
									_parser = [[ELM327ResponseParser alloc] initWithBytes:_readBuf length:_readBufLength];
								}
								else {
									[_parser setBytes:_readBuf length:_readBufLength];
								}
								
								NSArray* responses	= [_parser parseResponse:kScanToolProtocolNone];
								if(responses && [responses count] > 0) {									
									BOOL extendPIDSearch	= NO;
									
									for(FLScanToolResponse* resp in responses) {
										BOOL morePIDs		= [self buildSupportedSensorList:resp.data forPidGroup:_currentPIDGroup];										

										if (!extendPIDSearch && morePIDs) {
											extendPIDSearch	= YES;
										}
										
										FLDEBUG(@"More PIDs: %@", (morePIDs) ? @"YES" : @"NO")
									}
									
									if (extendPIDSearch) {
										_currentPIDGroup		+= (extendPIDSearch) ? 0x20 : 0x00;
										
										if (_currentPIDGroup > 0x40) {
											_initState			<<= 1;
											_currentPIDGroup	= 0x00;
										}
									}
									else {
										_initState				<<= 1;
										_currentPIDGroup		= 0x00;
									}								
								}
							}
						}
							break;
							
						case ELM327_INIT_STATE_CODES:	{
							_initState <<= 1;

						}
							break;
							
						case ELM327_INIT_STATE_CODES_PENDING:	{
							_initState <<= 1;
							
						}
							break;
							
						case ELM327_INIT_STATE_UNKNOWN:
						default:
							break;
					}
				}
				
				CLEAR_READBUF()
				
				if(INIT_COMPLETE(_initState)) {
					FLDEBUG(@"Init Complete", nil)
					_initState	= ELM327_INIT_STATE_COMPLETE;
					_currentPIDGroup	= 0x00;
					_state		= STATE_IDLE;
					[self invalidateInitTimer];
					[self dispatchDelegate:@selector(scanToolDidInitialize:) withObject:nil];
				}
				else {
					[self sendCommand:[self commandForInitState:_initState] initCommand:YES];
				}
			}
		}	
	}
	@catch (NSException* e) {
		FLEXCEPTION(e)
	}
	@finally {
	
	}	
}

- (void) readInput {
	FLTRACE_ENTRY
	@try {
		NSInteger readLength = [_inputStream read:&_readBuf[_readBufLength] maxLength:(sizeof(_readBuf) - _readBufLength)];
		FLDEBUG(@"Read %ld bytes", (long)readLength)
		FLDEBUG(@"_readBufLength = %ld", (long)_readBufLength)
		
		if (readLength != -1) {
			_readBufLength += readLength;
		}
		
		if(ELM_READ_COMPLETE(_readBuf, (_readBufLength-1))) {
			
			_state			= STATE_PROCESSING;
			
			// Trim the ending '\r\r>' characters
			_readBuf[(_readBufLength - 3)] = 0x00;
			_readBufLength			-= 3;
			
			char* asciistr			= (char*)_readBuf;
			FLDEBUG(@"Data Returned: %s", asciistr)
			
			if(ELM_ERROR(asciistr)) {
				FLERROR(@"Error response from ELM327 (state=%d): %s", _initState, asciistr)
				_initState	= ELM327_INIT_STATE_RESET;
				_state		= STATE_INIT;
			}
			else {
				if(!_parser) {
					_parser = [[ELM327ResponseParser alloc] initWithBytes:_readBuf length:_readBufLength];
				}
				else {
					[_parser setBytes:_readBuf length:_readBufLength];
				}
				
				NSArray* responses	= [_parser parseResponse:_protocol];
				if(responses) {
					[self dispatchDelegate:@selector(scanTool:didReceiveResponse:) withObject:responses];
				}
				else {
					[self dispatchDelegate:@selector(scanTool:didReceiveResponse:) withObject:nil];
				}

				
				_state = STATE_IDLE;
				[self sendCommand:[self dequeueCommand] initCommand:YES];
			}
		}	
		else {
			_state = STATE_WAITING;
		}
	}
	@catch (NSException * e) {
		FLEXCEPTION(e)
		CLEAR_READBUF()
		_state = STATE_INIT;
	}
	@finally {
		if(STATE_IDLE() || STATE_INIT()) {
			CLEAR_READBUF()
		}
	}
}


- (void) readVoltageResponse {
	FLTRACE_ENTRY
	@try {
		NSInteger readLength = [_inputStream read:&_readBuf[_readBufLength] maxLength:(sizeof(_readBuf) - _readBufLength)];
		FLDEBUG(@"Read %ld bytes", (long)readLength)
		_readBufLength += readLength;
		
		if(ELM_READ_COMPLETE(_readBuf, (_readBufLength-1))) {
			
			_state			= STATE_PROCESSING;
			
			// Trim the ending '\r\n>' characters
			_readBuf[(_readBufLength - 3)] = 0x00;
			_readBufLength			-= 3;
			
			char* asciistr			= (char*)_readBuf;
			FLDEBUG(@"Data Returned: %s", asciistr)
			
			if(ELM_ERROR(asciistr)) {
				FLERROR(@"Error response from ELM327 (state=%d): %s", _initState, asciistr)
				_initState	= ELM327_INIT_STATE_RESET;
				_state		= STATE_INIT;
			}
			else {				
				[self dispatchDelegate:@selector(scanTool:didReceiveVoltage:) withObject:[NSString stringWithCString:asciistr encoding:NSASCIIStringEncoding]];
				_state		= STATE_IDLE;
				[self sendCommand:[self dequeueCommand] initCommand:YES];
			}
		}	
		else {
			_state = STATE_WAITING;
		}
	}
	@catch (NSException* e) {
		FLEXCEPTION(e)
		CLEAR_READBUF()
		_state = STATE_INIT;
	}
	@finally {
		if(STATE_IDLE() || STATE_INIT()) {
			CLEAR_READBUF()
			_waitingForVoltageCommand	= NO;
		}
	}
}

#pragma mark -
#pragma mark NSStream Event Handling Methods

- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)eventCode {
	if(stream == _inputStream) {
		[self handleInputEvent:eventCode];
	}
	else if(stream == _outputStream) {
		[self handleOutputEvent:eventCode];
	}
	else {
		FLERROR(@"Received event for unknown stream", nil);
	}	
}



- (void)handleInputEvent:(NSStreamEvent)eventCode {
	
	if(_inputStream) {
		switch (eventCode) {
			case NSStreamEventNone:
				FLDEBUG(@"%@: NSStreamEventNone", _inputStream)
				break;
				
			case NSStreamEventOpenCompleted:
				FLDEBUG(@"%@: NSStreamEventOpenCompleted", _inputStream)
				
				break;
				
			case NSStreamEventHasBytesAvailable:
				FLDEBUG(@"%@: NSStreamEventHasBytesAvailable", _inputStream)
				
				if(STATE_INIT()) {
					[self readInitResponse];
				}
				else if(STATE_IDLE() || STATE_WAITING()) {
					if(!_waitingForVoltageCommand) {
						[self readInput];
					}
					else {
						[self readVoltageResponse];
					}					
				}
				else {
					FLERROR(@"Received bytes in unknown state: %d", _state)
				}
				
				break;
				
			case NSStreamEventErrorOccurred:
				FLERROR(@"NSStreamEventErrorOccurred", nil)
				
				NSError* error = [_inputStream streamError];
				
				FLNSERROR(error)
				
				[self dispatchDelegate:@selector(scanTool:didReceiveError:) withObject:error];
				
				break;
				
				
			case NSStreamEventEndEncountered:
				FLDEBUG(@"%@: NSStreamEventEndEncountered", _inputStream)
				break;
				
				// we don't write to input stream, so ignore this event
			case NSStreamEventHasSpaceAvailable:
				//FLINFO(@"NSStreamEventHasSpaceAvailable")
			default:
				break;
		}
		
	}	
}



- (void)handleOutputEvent:(NSStreamEvent)eventCode {
	if(_outputStream) {
		switch (eventCode) {
			case NSStreamEventNone:
				FLDEBUG(@"%@: NSStreamEventNone", _outputStream)
				break;
				
			case NSStreamEventOpenCompleted:
				FLDEBUG(@"%@: NSStreamEventOpenCompleted", _outputStream)
				break;
				
			case NSStreamEventHasBytesAvailable:
				FLDEBUG(@"%@: NSStreamEventHasBytesAvailable", _outputStream)
				break;
				
			case NSStreamEventErrorOccurred:
				FLERROR(@"NSStreamEventErrorOccurred", nil);
				NSError* error = [_outputStream streamError];				
				FLNSERROR(error);
				break;
				
			case NSStreamEventEndEncountered:
				FLDEBUG(@"%@: NSStreamEventEndEncountered", _outputStream);
				break;
				
			case NSStreamEventHasSpaceAvailable:
				FLDEBUG(@"%@: NSStreamEventHasSpaceAvailable", _outputStream)
				// Send whatever we have on hand
				[self writeCachedData];
				break;
			default:
				break;
		}
		
	}
}

#pragma mark -
#pragma mark ScanToolCommand Generators

- (FLScanToolCommand*) commandForGenericOBD:(FLScanToolMode)mode pid:(unsigned char)pid data:(NSData*)data {	
	return (FLScanToolCommand*)[ELM327Command commandForOBD2:mode pid:pid data:data];
}

- (FLScanToolCommand*) commandForReadVersionNumber {
	return (FLScanToolCommand*)[ELM327Command commandForReadVersionID];
}


- (FLScanToolCommand*) commandForReadProtocol {
	return (FLScanToolCommand*)[ELM327Command commandForReadProtocol];
}

- (FLScanToolCommand*) commandForGetBatteryVoltage {
	return (FLScanToolCommand*)[ELM327Command commandForReadVoltage];
}

@end
