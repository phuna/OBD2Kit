//
//  BasicScanViewController+ScanToolDelegate.m
//  BasicScan
//
//  Created by Alko on 25/11/13.
//
//

#import "BasicScanViewController.h"

#import "FLECUSensor.h"

@implementation BasicScanViewController (ScanToolDelegate)

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
            sensorLabel = self.tempLabel;
            break;
    }
    
    
    [self showSensorValue:sensor onLabel:sensorLabel];
}

- (void)showSensorValue:(FLECUSensor*)sensor onLabel:(UILabel*)label
{
    NSString *sensorValue = [NSString stringWithFormat:@"%@ %@",
                             [sensor valueStringForMeasurement1:NO],
                             [sensor imperialUnitString]];
    
    [label setText:sensorValue];
    [label setNeedsDisplay];
}

- (void)scanDidStart:(FLScanTool*)scanTool
{
    
}

- (void)scanDidPause:(FLScanTool*)scanTool
{
    
}

- (void)scanDidCancel:(FLScanTool*)scanTool
{
    
}

- (void)scanToolDidConnect:(FLScanTool*)scanTool
{
    
}

- (void)scanToolDidDisconnect:(FLScanTool*)scanTool
{
    
}

- (void)scanToolWillSleep:(FLScanTool*)scanTool
{
    
}

- (void)scanToolDidFailToInitialize:(FLScanTool*)scanTool
{
    
}

- (void)scanTool:(FLScanTool*)scanTool didSendCommand:(FLScanToolCommand*)command
{
    
}

- (void)scanTool:(FLScanTool*)scanTool didReceiveVoltage:(NSString*)voltage
{
    
}

- (void)scanTool:(FLScanTool*)scanTool didTimeoutOnCommand:(FLScanToolCommand*)command
{
    
}

- (void)scanTool:(FLScanTool*)scanTool didReceiveError:(NSError*)error
{
    
}

@end
