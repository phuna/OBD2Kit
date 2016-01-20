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

@property (weak, nonatomic) IBOutlet UITextField *hostIpAddress;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;

@property (weak, nonatomic) IBOutlet UILabel* statusLabel;
@property (weak, nonatomic) IBOutlet UILabel* scanToolNameLabel;

@end


@implementation BasicScanViewController

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

    // Set a default IP address
    self.hostIpAddress.text = @"192.168.1.66";
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (IBAction)scanButtonClicked:(id)sender
{
    if ([self.scanButton.currentTitle isEqual: @"Start"]) {
        [self.scanButton setTitle:@"Stop" forState:UIControlStateNormal];
        [self startScan];
    } else {
        [self stopScan];
        [self.scanButton setTitle:@"Start" forState:UIControlStateNormal];
    }
}

- (void)startScan
{
    self.statusLabel.text = @"Initializing...";
	
    ELM327 *scanTool = [ELM327 scanToolWithHost:self.hostIpAddress.text andPort:35000];
	[scanTool setUseLocation:YES];
    [scanTool setDelegate:self];
    [scanTool startScanWithSensors:^NSArray *{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"Scanning...";
            self.scanToolNameLabel.text = scanTool.scanToolName;
        });
        
        NSArray *sensors = @[@(OBD2SensorEngineRPM),
                             @(OBD2SensorVehicleSpeed),
                             @(OBD2SensorOxygenSensorsPresent)];
        
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
