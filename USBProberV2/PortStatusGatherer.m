//
//  PortStatusGatherer.m
//  USBProber
//
//  Created by Russvogel on 10/14/10.
//  Copyright 2010 Apple. All rights reserved.
//

#import "PortStatusGatherer.h"


@interface PortStatusGatherer (Private)

@end

@implementation PortStatusGatherer

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/usb/USB.h>

#include <AvailabilityMacros.h>

// Set the following to 1 when you don't want to support SSpeed in Zin, previous to a seed:
#if 0
	#if defined(MAC_OS_X_VERSION_10_8)
	    #undef SUPPORTS_SS_USB
	#else
	    #define SUPPORTS_SS_USB 1
	#endif
#else
	#define SUPPORTS_SS_USB 1
#endif

//============= Stuff from USBHub.h that is not public =============

/*!
 @enum HubPortStatus
 @discussion Used to decode the Port Status and Change 
 */
enum {
	kSSHubPortStatusConnectionBit	= 0,
	kSSHubPortStatusEnabledBit		= 1,
	kSSHubPortStatusOverCurrentBit	= 3,
	kSSHubPortStatusResetBit		= 4,
	
#ifdef SUPPORTS_SS_USB
	// USB 3.0
	kSSHubPortStatusLinkStateShift		= 5,
	kSSHubPortStatusPowerBit			= 9,
	kSSHubPortStatusSpeedShift			= 10,
	kSSHubPortChangeBHResetBit			= 5,
	kSSHubPortChangePortLinkStateBit 	= 6,
	kSSHubPortChangePortConfigErrBit	= 7,
#endif
	
    kHubPortConnection		= 0x0001,
    kHubPortEnabled			= 0x0002,
    kHubPortSuspend			= 0x0004,
    kHubPortOverCurrent		= 0x0008,
    kHubPortBeingReset		= 0x0010,
    kHubPortPower			= 0x0100,
    kHubPortLowSpeed		= 0x0200,
    kHubPortHighSpeed		= 0x0400,
    kHubPortTestMode		= 0x0800,
    kHubPortIndicator		= 0x1000,
#ifdef SUPPORTS_SS_USB
    kHubPortSuperSpeed		= 0x2000,					// This is a synthesized bit that is using a reserved bit from the Hub Port Status definition in USB 2.0.
	
	// USB 3.0
	kSSHubPortStatusConnectionMask	= ( 1 << kSSHubPortStatusConnectionBit ),
	kSSHubPortStatusEnabledMask		= ( 1 << kSSHubPortStatusEnabledBit ),
	kSSHubPortStatusOverCurrentMask	= ( 1 << kSSHubPortStatusOverCurrentBit ),
	kSSHubPortStatusBeingResetMask	= ( 1 << kSSHubPortStatusResetBit ),
    kSSHubPortStatusLinkStateMask	= 0x01E0,
    kSSHubPortStatusPowerMask		= ( 1 << kSSHubPortStatusPowerBit ),
	kSSHubPortStatusSpeedMask		= 0x1C00,
	kSSHubPortChangeBHResetMask		= ( 1 << kSSHubPortChangeBHResetBit ),
	kSSHubPortChangePortLinkStateMask = ( 1 << kSSHubPortChangePortLinkStateBit ),
	kSSHubPortChangePortConfigErrMask = ( 1 << kSSHubPortChangePortConfigErrBit ),
	
	kSSHubPortLinkStateU0			= 0,
	kSSHubPortLinkStateU1			= 1,
	kSSHubPortLinkStateU2			= 2,
	kSSHubPortLinkStateU3			= 3,
	kSSHubPortLinkStateSSDisabled	= 4,
	kSSHubPortLinkStateRxDetect		= 5,
	kSSHubPortLinkStateSSInactive	= 6,
	kSSHubPortLinkStatePolling		= 7,
	kSSHubPortLinkStateRecovery		= 8,
	kSSHubPortLinkStateHotReset		= 9,
	kSSHubPortLinkStateComplianceMode	= 10,
	kSSHubPortLinkStateLoopBack		= 11,
#endif

    // these are the bits which cause the hub port state machine to keep moving (USB 2.0)
    kHubPortStateChangeMask		= (kHubPortConnection | kHubPortEnabled | kHubPortSuspend | kHubPortOverCurrent | kHubPortBeingReset)

};

struct IOUSBHubStatus {
    UInt16          statusFlags;
    UInt16          changeFlags;
};
typedef struct IOUSBHubStatus   IOUSBHubStatus;
typedef IOUSBHubStatus *    IOUSBHubStatusPtr;

typedef struct IOUSBHubStatus   IOUSBHubPortStatus;

#ifdef SUPPORTS_SS_USB
/*!
 @enum USB 3 Hub Class Request
 @discussion Specifies values for the bRequest field of a Device Request.
 */
enum {
	kUSBHubRqSetHubDepth	= 12,
	kUSBHubRqGetPortErrorCount	= 13
};
#endif

//==============================================================================================



- initWithListener:(id <PortStatusGathererListener>)listener rootNode:(OutlineViewNode *)rootNode 
{

    if (self = [super init]) 
	{
        _listener = listener;
        _rootNode = [rootNode retain];
	}

	return self;
}

- (void)dealloc 
{
	[_rootNode release];
	[super dealloc];
}

#ifdef SUPPORTS_SS_USB
- (NSMutableString *) decodeSSPortStatus:(IOUSBHubPortStatus) portStatus
{
	NSMutableString * portStatusString = [[NSMutableString alloc] initWithCapacity:1];
	UInt16 status = portStatus.statusFlags;
	UInt16 change = portStatus.changeFlags;

	[portStatusString setString:@"STATUS(change): "];
	
	if (status & kHubPortConnection || change & kHubPortConnection)
	{
		NSString * tempIndicator = @"CONNECT ";
		if( change & kHubPortConnection)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortEnabled || change & kHubPortEnabled)
	{
		NSString * tempIndicator = @"ENABLE ";
		if( change & kHubPortEnabled)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}

	if (status & kHubPortOverCurrent || change & kHubPortOverCurrent)
	{
		NSString * tempIndicator = @"OVER-I ";
		if( change & kHubPortOverCurrent)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortBeingReset || change & kHubPortBeingReset)
	{
		NSString * tempIndicator = @"RESET ";
		if( change & kHubPortBeingReset)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	
	if (change & kSSHubPortChangeBHResetMask)
		[portStatusString appendString:@"bh_reset "];
	
	if (change & kSSHubPortChangePortLinkStateMask)
		[portStatusString appendString:@"linkState "];
	
	if (change & kSSHubPortChangePortConfigErrMask)
		[portStatusString appendString:@"configErr "];
	
	if (status & kSSHubPortStatusPowerBit)
		[portStatusString appendString:@"POWER "];
	
	// Port Speed
	if ( (status & kSSHubPortStatusSpeedMask) == 0)
		[portStatusString appendString:@"SuperSpeed "];
	
	// Link State
	[portStatusString appendString:@" -- Link State: "];
	switch ( (status & kSSHubPortStatusLinkStateMask) >> kSSHubPortStatusLinkStateShift)
	{
		case 0:									
			[portStatusString appendString:@"U0"];
			break;
		case 1:									
			[portStatusString appendString:@"U1 "];
			break;
		case 2:									
			[portStatusString appendString:@"U2 "];
			break;
		case 3:									
			[portStatusString appendString:@"U3 "];
			break;
		case 4:									
			[portStatusString appendString:@"SS.Disabled"];
			break;
		case 5:									
			[portStatusString appendString:@"Rx.Detect"];
			break;
		case 6:									
			[portStatusString appendString:@"SS.Inactive "];
			break;
		case 7:									
			[portStatusString appendString:@"Polling"];
			break;
		case 8:									
			[portStatusString appendString:@"Recovery "];
			break;
		case 9:									
			[portStatusString appendString:@"Hot Reset "];
			break;
		case 0xA:									
			[portStatusString appendString:@"Compliance Mode "];
			break;
		case 0xB:									
			[portStatusString appendString:@"Loopback "];
			break;
		case 0xC:									
		case 0xD:									
		case 0xE:									
		case 0xF:									
			[portStatusString appendString:@"Reserved "];
			break;
	}
	
	return portStatusString;
}
#endif

- (NSMutableString *) decodePortStatus:(IOUSBHubPortStatus) portStatus
{
	NSMutableString * portStatusString = [[NSMutableString alloc] initWithCapacity:1];
	UInt16 status = portStatus.statusFlags;
	UInt16 change = portStatus.changeFlags;
	
	[portStatusString setString:@"STATUS(change): "];
	
	if (status & kHubPortConnection || change & kHubPortConnection)
	{
		NSString * tempIndicator = @"CONNECT ";
		if( change & kHubPortConnection)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortEnabled || change & kHubPortEnabled)
	{
		NSString * tempIndicator = @"ENABLE ";
		if( change & kHubPortEnabled)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortSuspend || change & kHubPortSuspend)
	{
		NSString * tempIndicator = @"SUSPEND ";
		if( change & kHubPortSuspend)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortOverCurrent || change & kHubPortOverCurrent)
	{
		NSString * tempIndicator = @"OVER-I ";
		if( change & kHubPortOverCurrent)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	if (status & kHubPortBeingReset || change & kHubPortBeingReset)
	{
		NSString * tempIndicator = @"RESET ";
		if( change & kHubPortBeingReset)
			tempIndicator = [tempIndicator lowercaseString];
		[portStatusString appendString:tempIndicator];
	}
	
	if (status & kHubPortPower)
		[portStatusString appendString:@"POWER "];
	
	// Port Speed
	if (status & kHubPortLowSpeed)
		[portStatusString appendString:@"Low Speed "];
	else if (status & kHubPortHighSpeed)
		[portStatusString appendString:@"High Speed "];
	else
		[portStatusString appendString:@"Full Speed "];
	
	if (status & kHubPortTestMode)
		[portStatusString appendString:@"TEST "];
	
	if (status & kHubPortIndicator)
		[portStatusString appendString:@"INDICATOR "];
	
	return portStatusString;
}


- (NSString *) PrintNameForPortAtLocation:(int) port withLocationID:(uint32_t) parentLocationID deviceSpeed:(int)deviceSpeed bandwidth:(UInt32 *)bandwidth
{
	io_iterator_t				matchingServicesIterator;
    kern_return_t				kernResult; 
    CFMutableDictionaryRef		matchingDict;
    CFMutableDictionaryRef		propertyMatchDict;
    io_service_t				usbDeviceRef;
	uint32_t					locationID = 0;
	int							nibble = 5;
	NSMutableString *			returnString = [[NSMutableString alloc] initWithCapacity:1] ;
	[returnString setString:@""];
    
#ifdef SUPPORTS_SS_USB
	// SS devices have an extra bit that we need to temporarily remove to look at the first non-zero nibble
	if (deviceSpeed == kUSBDeviceSpeedSuper )
	{
		parentLocationID &= 0xff7FFFFF;
	}
#endif
	
	// First, create the locationID for the port
	// Start looking at the nibble at the 3rd nibble for a 0
	while ( parentLocationID & (0xf << (4 * nibble)) )
	{
		nibble--;
	}
	
	locationID = parentLocationID | (port << (4*nibble));
	
#ifdef SUPPORTS_SS_USB
	// Add back the ss bit
	if (deviceSpeed == kUSBDeviceSpeedSuper )
	{
		locationID |= 0x00800000;
	}
#endif
									 
    // IOServiceMatching is a convenience function to create a dictionary with the key kIOProviderClassKey and 
    // the specified value.
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	
    if (NULL == matchingDict) 
	{
        NSLog(@"IOServiceMatching returned a NULL dictionary.\n");
		goto ErrorExit;
    }
    else 
	{
		propertyMatchDict = CFDictionaryCreateMutable( kCFAllocatorDefault, 0,
												  &kCFTypeDictionaryKeyCallBacks,
												  &kCFTypeDictionaryValueCallBacks);
    }
	
	if (NULL == propertyMatchDict)
	{
		CFRelease(matchingDict);
		NSLog(@"CFDictionaryCreateMutable returned a NULL dictionary.\n");
		goto ErrorExit;
	}
	else 
	{
		// Set the value in the dictionary of the property with the given key, or add the key 
		// to the dictionary if it doesn't exist. This call retains the value object passed in.
		CFNumberRef locationIDRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &locationID);
		CFDictionarySetValue(propertyMatchDict, CFSTR("locationID"), locationIDRef); 
		
		// Now add the dictionary containing the matching value to our main
		// matching dictionary. This call will retain propertyMatchDict, so we can release our reference 
		// on propertyMatchDict after adding it to matchingDict.
		CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey), propertyMatchDict);
		CFRelease(propertyMatchDict);
		CFRelease(locationIDRef);
	}
		
    // IOServiceGetMatchingServices retains the returned iterator, so release the iterator when we're done with it.
    // IOServiceGetMatchingServices also consumes a reference on the matching dictionary so we don't need to release
    // the dictionary explicitly.
    kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServicesIterator);    
    if (KERN_SUCCESS != kernResult) 
	{
        NSLog(@"IOServiceGetMatchingServices returned 0x%08x\n", kernResult);
		goto ErrorExit;
    }

    while ( (usbDeviceRef = IOIteratorNext(matchingServicesIterator)) )
    {
		io_name_t	name;
#ifdef SUPPORTS_SS_USB
		IOCFPlugInInterface				**iodev = NULL;		// requires <IOKit/IOCFPlugIn.h>
		IOUSBDeviceInterface500			**dev = NULL;
		SInt32							score;
		IOReturn						err;
		
		err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
		if (err || !*iodev || !iodev)
		{
			NSLog(@"PortStatusGather PrintNameForPortAtLocation: unable to create plugin. ret = %08x, iodev = %p\n", err, iodev);
			break;
		}
		err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID500), (LPVOID)&dev);
		IODestroyPlugInInterface(iodev);				// done with this
		
		if (err || !*dev || !dev)
		{
			NSLog(@"PortStatusGather  PrintNameForPortAtLocation: unable to create a device interface. ret = %08x, dev = %p\n", err, dev);
			break;
		}
		err = (*dev)->GetBandwidthAvailableForDevice(dev, bandwidth);
#endif

		kernResult = IORegistryEntryGetName(usbDeviceRef, name);
		if (KERN_SUCCESS != kernResult) 
		{
			[returnString appendString: [NSString stringWithFormat:@"  Unknown"]];
		}
		else
		{
			[returnString appendString: [NSString stringWithFormat:@"  %s", name]];
		}
		IOObjectRelease(usbDeviceRef);			// no longer need this reference
    }
	
ErrorExit:
	return returnString;
}

#ifdef SUPPORTS_SS_USB
- (int) getPortErrorCount:(IOUSBDeviceInterface500 **) dev port:(int)port
{
	IOUSBDevRequest		request;
	UInt16				errorCount = 0;
	IOReturn			err;
	
	request.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBOther);
	request.bRequest = kUSBHubRqGetPortErrorCount;
	request.wValue = 0;
	request.wIndex = port;
	request.wLength = sizeof(UInt16);
	request.pData = &errorCount;
	request.wLenDone = 0;
	
	err = (*dev)->DeviceRequest(dev, &request);
	if ( err != kIOReturnSuccess)
	{
		NSLog(@"PortStatusGather getPortErrorCount: DeviceRequest ret = 0x%08x\n", err);
	}
	
	return errorCount;
	
}
#endif

- (IOReturn) dealWithDevice:(io_service_t) usbDeviceRef
{
    IOReturn						err;
    IOCFPlugInInterface				**iodev = NULL;		// requires <IOKit/IOCFPlugIn.h>
#ifdef SUPPORTS_SS_USB
    IOUSBDeviceInterface500			**dev = NULL;
#else
    IOUSBDeviceInterface320			**dev = NULL;
#endif
    SInt32							score;
	uint32_t						locationID = 0;
	uint32_t						ports = 0;
	CFNumberRef						numberObj;
	int								port;
    io_name_t						name;
	OutlineViewNode *				aDeviceNode = nil;
	OutlineViewNode *				aPortNode = nil;
	UInt8							deviceSpeed = 0;
#ifdef SUPPORTS_SS_USB
	UInt32							bandwidth = 0;
#endif	
    err = IOCreatePlugInInterfaceForService(usbDeviceRef, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
    if (err || !*iodev || !iodev)
    {
		NSLog(@"PortStatusGather dealWithDevice: unable to create plugin. ret = %08x, iodev = %p\n", err, iodev);
		goto finish;
    }
#ifdef SUPPORTS_SS_USB
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID500), (LPVOID)&dev);
#else
    err = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID)&dev);
#endif
	IODestroyPlugInInterface(iodev);				// done with this
	
    if (err || !*dev || !dev)
    {
		NSLog(@"PortStatusGather  dealWithDevice: unable to create a device interface. ret = %08x, dev = %p\n", err, dev);
 		goto finish;
	}
	
	(void) IORegistryEntryGetName(usbDeviceRef, name);
	numberObj = IORegistryEntryCreateCFProperty(usbDeviceRef, CFSTR("locationID"), kCFAllocatorDefault, 0);
	if ( numberObj )
	{
		CFNumberGetValue(numberObj, kCFNumberSInt32Type, &locationID);
		CFRelease(numberObj);
		
		// If the "Ports" property exists, use that.  If not, default to 7.
		numberObj = IORegistryEntryCreateCFProperty(usbDeviceRef, CFSTR("Ports"), kCFAllocatorDefault, 0);
		if ( numberObj )
		{
			CFNumberGetValue(numberObj, kCFNumberSInt32Type, &ports);
			CFRelease(numberObj);
		}
		else 
		{
			ports = 7;
		}
		
#ifdef SUPPORTS_SS_USB
		err = (*dev)->GetBandwidthAvailableForDevice(dev, &bandwidth);
#endif
		
		// aDeviceNode  =  [[OutlineViewNode alloc] initWithName:@"DeviceInfo" value:[NSString stringWithFormat:@"Hub (%s) @ 0x%8.8x with %d ports (Available Bandwidth: %d)", name, locationID, ports, bandwidth]];
		aDeviceNode  =  [[OutlineViewNode alloc] initWithName:@"DeviceInfo" value:[NSString stringWithFormat:@"Hub (%s) @ 0x%8.8x with %d ports", name, locationID, ports]];
		[_rootNode addChild:aDeviceNode ];
		[aDeviceNode release];
	}	
	
	err = (*dev)->GetDeviceSpeed(dev, &deviceSpeed);
	if ( err != kIOReturnSuccess)
	{
		NSLog(@"PortStatusGather dealWithDevice: GetDeviceSpeed ret = 0x%08x\n", err);
	}
	
	// Iterate through all the ports and get the status/change info
	for ( port = 1; port <= ports ; port++ )
	{
		IOUSBDevRequest		request;
		IOUSBHubPortStatus	status;
		UInt32				bandwidth = 0;
		
		usleep(1000);
		request.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBOther);
		request.bRequest = kUSBRqGetStatus;
		request.wValue = 0;
		request.wIndex = port;
		request.wLength = sizeof(IOUSBHubPortStatus);
		request.pData = &status;
		request.wLenDone = 0;
		
		err = (*dev)->DeviceRequest(dev, &request);
		
		NSMutableString * portString = [[NSMutableString alloc] initWithCapacity:1];
		[portString setString: [NSString stringWithFormat:@"Port %d:  ", port]];
		
		if ( err == kIOReturnSuccess)
		{
			// Get things the right way round.
			status.statusFlags = USBToHostWord(status.statusFlags);
			status.changeFlags = USBToHostWord(status.changeFlags);
			[portString appendString: [NSString stringWithFormat:@"Status: 0x%4.4x  Change: 0x%4.4x", status.statusFlags, status.changeFlags]];
			
			if ( status.statusFlags & kHubPortConnection )
			{
				NSString * portAppendString = [self PrintNameForPortAtLocation:port withLocationID:locationID deviceSpeed:deviceSpeed bandwidth:&bandwidth];
				[portString appendString: portAppendString];
				[portAppendString release];
			}
		}
		else if ( err == kIOReturnNotResponding )
		{
			[portString appendString:[NSString stringWithFormat:@" Not Responding"]];
		}
		else if ( err == kIOUSBPipeStalled )
		{
			[portString appendString:[NSString stringWithFormat:@" Pipe Stalled"]];
		}
		else
		{
			[portString appendString: [NSString stringWithFormat:@"(*dev)->DeviceRequest err: 0x%4.4x ", err]];
		}								
		
		aPortNode  =  [[OutlineViewNode alloc] initWithName:@"PortInfo" value:portString];
		[aDeviceNode addChild:aPortNode ];
		[portString release];
		
		if ( err == kIOReturnSuccess)
		{
			NSMutableString *bitStatusChangeString = NULL;
			
#ifdef SUPPORTS_SS_USB
			if (deviceSpeed == kUSBDeviceSpeedSuper )
			{
				bitStatusChangeString = [self decodeSSPortStatus: status];
			}
			else
#endif
			{
				bitStatusChangeString = [self decodePortStatus: status];
			}
			
			if( [bitStatusChangeString length] > 0 )
			{
				OutlineViewNode *aNode  =  [[OutlineViewNode alloc] initWithName:@"StatusBits" value:bitStatusChangeString];
				[aPortNode addChild:aNode ];
				[aNode release];
				[bitStatusChangeString release];
			}
#ifdef SUPPORTS_SS_USB
			if (deviceSpeed == kUSBDeviceSpeedSuper )
			{
				NSMutableString * errorCountString = [[NSMutableString alloc] initWithCapacity:1];
				
				// Update with the error count
				[errorCountString appendString:[NSString stringWithFormat:@"Error Count: %d ", [self getPortErrorCount:dev port:port]]];
				if( [errorCountString length] > 0 )
				{
					OutlineViewNode *aNode  =  [[OutlineViewNode alloc] initWithName:@"ErrorCount" value:errorCountString];
					[aPortNode addChild:aNode ];
					[aNode release];
				}
				[errorCountString release];
			}

			NSMutableString * bandwidthString = [[NSMutableString alloc] initWithCapacity:1];
			[bandwidthString appendString:[NSString stringWithFormat:@"Bandwidth Available: %d bytes per %s", bandwidth, (deviceSpeed == kUSBDeviceSpeedSuper || deviceSpeed == kUSBDeviceSpeedHigh) ? "microframe" : "frame"]];
			if( [bandwidthString length] > 0 )
			{
				OutlineViewNode *aNode  =  [[OutlineViewNode alloc] initWithName:@"Bandwidth" value:bandwidthString];
				[aPortNode addChild:aNode ];
				[aNode release];
			}
			[bandwidthString release];
#endif
		}
		[aPortNode release];
	}
	
finish:
	if (dev)
	{
		err = (*dev)->Release(dev);
		if (err)
		{
			NSLog( @"dealWithDevice: error releasing device - %08x\n", err);
		}
	}
	
	return err;
}



- (IOReturn) gatherStatus
{
    IOReturn			err = kIOReturnSuccess;
    CFMutableDictionaryRef 	matchingDictionary = 0;		// requires <IOKit/IOKitLib.h>
    SInt32					bDeviceClass = 9;
    SInt32					bDeviceSubClass = 0;
    CFNumberRef				numberRef;
    io_iterator_t			iterator = 0;
    io_service_t			usbDeviceRef;
	
    [_rootNode removeAllChildren];
	
    matchingDictionary = IOServiceMatching(kIOUSBDeviceClassName);	// requires <IOKit/usb/IOUSBLib.h>
    if (!matchingDictionary)
    {
        NSLog(@"DumpHubPortStatus: could not create matching dictionary\n");
        err = kIOReturnError;
		goto finish;
    }
    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bDeviceClass);
    if (!numberRef)
    {
        NSLog(@"DumpHubPortStatus: could not create CFNumberRef for vendor\n");
        err = kIOReturnError;
		goto finish;
    }
	
	CFDictionaryAddValue(matchingDictionary, CFSTR(kUSBDeviceClass), numberRef);
	CFRelease(numberRef);
	numberRef = NULL;
	
	numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bDeviceSubClass);
	if (!numberRef)
	{
		NSLog(@"DumpHubPortStatus: could not create CFNumberRef for product\n");
		err = kIOReturnError;
		goto finish;
	}
	
	CFDictionaryAddValue(matchingDictionary, CFSTR(kUSBDeviceSubClass), CFSTR("*"));
	CFRelease(numberRef);
	numberRef = 0;
	
	err = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator);
	matchingDictionary = 0;			// this was consumed by the above call
	
	if( !err )
	{
		
		while ( (usbDeviceRef = IOIteratorNext(iterator)) )
		{
			[self dealWithDevice:usbDeviceRef];
			IOObjectRelease(usbDeviceRef);			// no longer need this reference
		}
    }
	
    IOObjectRelease(iterator);
    iterator = 0;
	
finish:
	if (matchingDictionary)
		CFRelease(matchingDictionary);
    return err;
}

@end
