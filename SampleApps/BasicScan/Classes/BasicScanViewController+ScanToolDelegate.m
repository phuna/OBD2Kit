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

- (void)scanTool:(FLScanTool *)scanTool didUpdateSensor:(FLECUSensor *)sensor
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

- (void)showSensorValue:(FLECUSensor *)sensor onLabel:(UILabel *)label
{
    NSString *sensorValue = [NSString stringWithFormat:@"%@ %@",
                             [sensor valueStringForMeasurement1:NO],
                             [sensor imperialUnitString]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [label setText:sensorValue];
    });
}

@end
