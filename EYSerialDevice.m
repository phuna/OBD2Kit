//
//  EYSerialDevice.m
//  OBD2Kit
//
//  Created by Eddie Kelley on 7/28/13.
//
//

#import "EYSerialDevice.h"

#import <IOKit/IOBSD.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>

@implementation EYSerialDevice
@synthesize modems = _modems;

+ (NSArray*) allModems{
	
	EYSerialDevice *device = [[[EYSerialDevice alloc] init] autorelease];
	[device findModems];
	return [device modems];
}

- (id) init{
	if (self = [super init]) {
		self.modems = [NSMutableArray arrayWithCapacity:0];
	}
	return self;
}

- (void)dealloc{
	self.modems = nil;
	[super dealloc];
}

- (kern_return_t) findModems{
	io_iterator_t matchingServices;
    kern_return_t       kernResult;
    mach_port_t         masterPort;
    CFMutableDictionaryRef  classesToMatch;
	
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOMasterPort returned %d\n", kernResult);
		goto exit;
    }
	
    // Serial devices are instances of class IOSerialBSDClient.
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        printf("IOServiceMatching returned a NULL dictionary.\n");
    }
    else {
        CFDictionarySetValue(classesToMatch,
                             CFSTR(kIOSerialBSDTypeKey),
                             CFSTR(kIOSerialBSDAllTypes));
		
        // Each serial device object has a property with key
        // kIOSerialBSDTypeKey and a value that is one of
        // kIOSerialBSDAllTypes, kIOSerialBSDModemType,
        // or kIOSerialBSDRS232Type. You can change the
        // matching dictionary to find other types of serial
        // devices by changing the last parameter in the above call
        // to CFDictionarySetValue.
    }
	
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, &matchingServices);
    if (KERN_SUCCESS != kernResult)
    {
        printf("IOServiceGetMatchingServices returned %d\n", kernResult);
		goto exit;
    }
	
	io_object_t     modemService;
    kernResult = KERN_FAILURE;
	
    // Initialize the returned path
    char deviceFilePath[MAXPATHLEN];
	*deviceFilePath = '\0';
	Boolean modemFound = false;
	
    // Iterate across all modems found. In this example, we exit after
    // finding the first modem.
	
    while ((!modemFound) && (modemService = IOIteratorNext(matchingServices)))
    {
        NSString*   deviceFilePath;
		
		// Get the callout device's path (/dev/cu.xxxxx).
		// The callout device should almost always be
		// used. You would use the dialin device (/dev/tty.xxxxx) when
		// monitoring a serial port for
		// incoming calls, for example, a fax listener.
		
		deviceFilePath = IORegistryEntryCreateCFProperty(modemService,
														 CFSTR(kIOCalloutDeviceKey),
														 kCFAllocatorDefault,
														 0);
		
        if (deviceFilePath)
        {
			[_modems addObject:[NSString stringWithString:deviceFilePath]];
        }
		
        // Release the io_service_t now that we are done with it.
		
		(void) IOObjectRelease(modemService);
		
		// Release the deviceFilePath object
		[deviceFilePath release];
    }
	
	IOObjectRelease(matchingServices);
	
exit:
    return kernResult;
	
}

@end
