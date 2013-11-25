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

#import "ELM327.h"

@interface BasicScanViewController ()

@property (nonatomic, strong) ELM327 *scanTool;

@end

@implementation BasicScanViewController

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self startScan];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self stopScan];
}

- (void)startScan
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
                             @(OBD2SensorEngineOilTemperature),
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

@end
