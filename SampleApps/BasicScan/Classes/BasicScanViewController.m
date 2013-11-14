/*
 *  BasicScanViewController.m
 *  BasicScan
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

#import "BasicScanViewController.h"

#import "FLLogging.h"
#import "FLECUSensor.h"
#import "ELM327.h"

@interface BasicScanViewController ()

@property (nonatomic, strong) ELM327 *scanTool;

@end

@implementation BasicScanViewController

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self scan];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self stopScan];
}

- (void)scan
{
	[self.statusLabel setText:@"Initializing..."];
	
    ELM327 *scanTool = [ELM327 scanToolWithHost:@"192.168.0.6" andPort:35000];
	[scanTool setUseLocation:YES];
    [scanTool setDelegate:self];
    [scanTool startScanWithSensors:^NSArray *{
        [self.statusLabel setText:@"Scanning..."];
        [self.scanToolNameLabel setText:scanTool.scanToolName];
        
        NSArray *sensors = @[@(OBD2SensorEngineRPM),
                             @(OBD2SensorVehicleSpeed),
                             ];
        
        return sensors;
    }];
    
    [self setScanTool:scanTool];
}

- (void)stopScan
{
    ELM327 *scanTool = self.scanTool;
    [scanTool cancelScan];
	[scanTool setSensorScanTargets:nil];
	[scanTool setDelegate:nil];
}

#pragma mark -
#pragma mark ScanToolDelegate Methods

- (void)scanDidStart:(FLScanTool*)scanTool {
	FLINFO(@"STARTED SCAN")
}

- (void)scanDidPause:(FLScanTool*)scanTool {
	FLINFO(@"PAUSED SCAN")
}

- (void)scanDidCancel:(FLScanTool*)scanTool {
	FLINFO(@"CANCELLED SCAN")
}

- (void)scanToolDidConnect:(FLScanTool*)scanTool {
	FLINFO(@"SCANTOOL CONNECTED")
}

- (void)scanToolDidDisconnect:(FLScanTool*)scanTool {
	FLINFO(@"SCANTOOL DISCONNECTED")
}


- (void)scanToolWillSleep:(FLScanTool*)scanTool {
	FLINFO(@"SCANTOOL SLEEP")
}

- (void)scanToolDidFailToInitialize:(FLScanTool*)scanTool {
	FLINFO(@"SCANTOOL INITIALIZATION FAILURE")
	FLDEBUG(@"scanTool.scanToolState: %u", scanTool.scanToolState)
	FLDEBUG(@"scanTool.supportedSensors count: %d", [scanTool.supportedSensors count])
}

- (void)scanTool:(FLScanTool*)scanTool didSendCommand:(FLScanToolCommand*)command {
	FLINFO(@"DID SEND COMMAND")
}

- (void)scanTool:(FLScanTool*)scanTool didUpdateSensor:(FLECUSensor*)sensor
{
    UILabel *sensorLabel = nil;
    
    switch (sensor.pid) {
        case OBD2SensorEngineRPM:
            sensorLabel = self.rpmLabel;
            break;
        case OBD2SensorVehicleSpeed:
            sensorLabel = self.speedLabel;
            break;
            
        default:
            break;
    }
    
    NSString *sensorValue = [NSString stringWithFormat:@"%@ %@",
                             [sensor valueStringForMeasurement1:NO],
                             [sensor imperialUnitString]];
    
    [sensorLabel setText:sensorValue];
    [sensorLabel setNeedsDisplay];
}


- (void)scanTool:(FLScanTool*)scanTool didReceiveVoltage:(NSString*)voltage {
	FLTRACE_ENTRY
}


- (void)scanTool:(FLScanTool*)scanTool didTimeoutOnCommand:(FLScanToolCommand*)command {
	FLINFO(@"DID TIMEOUT")
}


- (void)scanTool:(FLScanTool*)scanTool didReceiveError:(NSError*)error {
	FLINFO(@"DID RECEIVE ERROR")
	FLNSERROR(error)
}

@end
