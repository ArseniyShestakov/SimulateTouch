#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#include "Touch.h"
#include "Common.h"
#include "Screen.h"
#include "AlertBox.h"
#include "Task.h"

#define TOUCH_SENDER_ID_PLIST_FILE_NAME @"senderid.plist"

#define MAX_FINGER_INDEX 20

#define NOT_VALID 0
#define VALID 1
#define VALID_AT_NEXT_APPEND 2

#define EVENT_VALID_INDEX 0
#define EVENT_TYPE_INDEX 1
#define EVENT_X_INDEX 2
#define EVENT_Y_INDEX 3

// device screen size
static CGFloat device_screen_width = 0;
static CGFloat device_screen_height = 0;

IOHIDEventSystemClientRef ioHIDEventSystemForSenderID = NULL;

// touch event sender id
unsigned long long int senderID = 0x0;


// valid type x y
static int eventsToAppend[MAX_FINGER_INDEX][4];

/*
get count from data array by socket
*/
static int getTouchCountFromDataArray(UInt8* dataArray)
{
	int count = (dataArray[0] - '0');
	return count;
}

/*
get type from data array by socket
*/
static int getTouchTypeFromDataArray(UInt8* dataArray, int index)
{
	int type = (dataArray[1+index*TOUCH_DATA_LEN] - '0');
	return type;
}

/*
get index from data array by socket
*/
static int getTouchIndexFromDataArray(UInt8* dataArray, int index)
{
	int touchIndex = 0;
	for (int i = 2; i <= 3; i++)
	{
		touchIndex += (dataArray[i+index*TOUCH_DATA_LEN] - '0')*pow(10, 3-i);
	}
	return touchIndex;
}

/*
get x from data array by socket
*/
static float getTouchXFromDataArray(UInt8* dataArray, int index)
{
	int x = 0;
	for (int i = 4; i <= 8; i++)
	{
		x += (dataArray[i+index*TOUCH_DATA_LEN] - '0')*pow(10, 8-i);
	}
	return x/10.0;
}


/*
get y from data array by socket
*/
static float getTouchYFromDataArray(UInt8* dataArray, int index)
{
	int y = 0;
	for (int i = 9; i <= 13; i++)
	{
		y += (dataArray[i+index*TOUCH_DATA_LEN] - '0')*pow(10, 13-i);
	}
	return y/10.0;
}

/*
Get the child event of touching down.
index: index of the finger
x: coordinate x of the screen (before conversion)
y: coordinate y of the screen (before conversion)
*/
static IOHIDEventRef generateChildEventTouchDown(int index, float x, float y)
{
	IOHIDEventRef child = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, mach_absolute_time(), index, 3, 3, x/device_screen_width, y/device_screen_height, 0.0f, 0.0f, 0.0f, 1, 1, 0);
    IOHIDEventSetFloatValue(child, 0xb0014, 0.04f); //set the major index getRandomNumberFloat(0.03, 0.05)
    IOHIDEventSetFloatValue(child, 0xb0015, 0.04f); //set the minor index
	return child;
}

/*
Get the child event of touching move. 
index: index of the finger
x: coordinate x of the screen (before conversion)
y: coordinate y of the screen (before conversion)
*/
static IOHIDEventRef generateChildEventTouchMove(int index, float x, float y)
{
	IOHIDEventRef child = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, mach_absolute_time(), index, 3, 4, x/device_screen_width, y/device_screen_height, 0.0f, 0.0f, 0.0f, 1, 1, 0);
    IOHIDEventSetFloatValue(child, 0xb0014, 0.04f); //set the major index
    IOHIDEventSetFloatValue(child, 0xb0015, 0.04f); //set the minor index
	return child;
}

/*
Get the child event of touching up.
index: index of the finger
x: coordinate x of the screen (before conversion)
y: coordinate y of the screen (before conversion)
*/
static IOHIDEventRef generateChildEventTouchUp(int index, float x, float y)
{
	IOHIDEventRef child = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault, mach_absolute_time(), index, 3, 2, x/device_screen_width, y/device_screen_height, 0.0f, 0.0f, 0.0f, 0, 0, 0);
    IOHIDEventSetFloatValue(child, 0xb0014, 0.04f); //set the major index
    IOHIDEventSetFloatValue(child, 0xb0015, 0.04f); //set the minor index
	return child;
}

/**
Append child event to parent
*/
static void appendChildEvent(IOHIDEventRef parent, int type, int index, float x, float y)
{
    switch (type)
    {
        case TOUCH_MOVE:
			IOHIDEventAppendEvent(parent, generateChildEventTouchMove(index, x, y));
            break;
        case TOUCH_DOWN:
            IOHIDEventAppendEvent(parent, generateChildEventTouchDown(index, x, y));
            break;
        case TOUCH_UP:
            IOHIDEventAppendEvent(parent, generateChildEventTouchUp(index, x, y));
            break;
        default:
            NSLog(@"com.zjx.springboard: Unknown touch event type in appendChildEvent, type: %d", type);
    }
}


/**
Perform touch events with data received from socket
*/
void performTouchFromRawData(UInt8 *eventData)
{
    // generate a parent event
	IOHIDEventRef parent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, mach_absolute_time(), 3, 99, 1, 0, 0, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0, 0, 0); 
    IOHIDEventSetIntegerValue(parent , 0xb0019, 1); //set flags of parent event   flags: 0x20001 -> 0xa0001
    IOHIDEventSetIntegerValue(parent , 0x4, 1); //set flags of parent event   flags: 0xa0001 -> 0xa0011

    for (int i = 0; i < getTouchCountFromDataArray(eventData); i++)
    {
        //NSLog(@"### com.zjx.springboard: get data. index: %d. type: %d. touchIndex: %d. x: %f. y: %f", i, getTouchTypeFromDataArray(eventData, i), getTouchIndexFromDataArray(eventData, i), getTouchXFromDataArray(eventData, i), getTouchYFromDataArray(eventData, i));
        int touchType = getTouchTypeFromDataArray(eventData, i);
        int x = getTouchXFromDataArray(eventData, i);
        int y = getTouchYFromDataArray(eventData, i);
        int index = getTouchIndexFromDataArray(eventData, i);

        appendChildEvent(parent, touchType, index, x, y); // append child event to parent

        switch (touchType)
        {
            case TOUCH_MOVE:
                eventsToAppend[index][EVENT_VALID_INDEX] = VALID_AT_NEXT_APPEND;
                eventsToAppend[index][EVENT_TYPE_INDEX] = TOUCH_MOVE;
                eventsToAppend[index][EVENT_X_INDEX] = (int)x;
                eventsToAppend[index][EVENT_Y_INDEX] = (int)y;
                break;
            case TOUCH_DOWN:
                eventsToAppend[index][EVENT_VALID_INDEX] = VALID_AT_NEXT_APPEND;
                eventsToAppend[index][EVENT_TYPE_INDEX] = TOUCH_DOWN;
                eventsToAppend[index][EVENT_X_INDEX] = (int)x; //!!!!!!directly converting to int may couse some precision problems
                eventsToAppend[index][EVENT_Y_INDEX] = (int)y; //!!!
                break;
            case TOUCH_UP:
                eventsToAppend[index][EVENT_VALID_INDEX] = NOT_VALID;
                break;
        }

    }

    for (int i = 0; i < MAX_FINGER_INDEX; i++)
    {
        if (eventsToAppend[i][EVENT_VALID_INDEX] == VALID)
        {
            //NSLog(@"com.zjx.springboard: appending event for finger: %d. type: %d. x: %d. y: %d", i, eventsToAppend[i][EVENT_TYPE_INDEX], eventsToAppend[i][EVENT_X_INDEX], eventsToAppend[i][EVENT_Y_INDEX]);
            appendChildEvent(parent, eventsToAppend[i][EVENT_TYPE_INDEX], i, eventsToAppend[i][EVENT_X_INDEX], eventsToAppend[i][EVENT_Y_INDEX]);
        }
        else if (eventsToAppend[i][EVENT_VALID_INDEX] == VALID_AT_NEXT_APPEND) // make it valid
        {
            //NSLog(@"com.zjx.springboard:  finger: %d to become valid. type: %d. x: %d. y: %d", i, eventsToAppend[i][EVENT_TYPE_INDEX], eventsToAppend[i][EVENT_X_INDEX], eventsToAppend[i][EVENT_Y_INDEX]);
            eventsToAppend[i][EVENT_VALID_INDEX] = VALID;
        }
    }

    IOHIDEventSetIntegerValue(parent, 0xb0007, 0x23);
    IOHIDEventSetIntegerValue(parent, 0xb0008, 0x1);
    IOHIDEventSetIntegerValue(parent, 0xb0009, 0x1);

    postIOHIDEvent(parent);
    CFRelease(parent);
}

/**
Post the parent event
*/
static void postIOHIDEvent(IOHIDEventRef event)
{
    static IOHIDEventSystemClientRef ioSystemClient = NULL;
    if (!ioSystemClient){
        ioSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
	if (senderID != 0)
    	IOHIDEventSetSenderID(event, senderID);
	else
	{		
		NSLog(@"### com.zjx.springboard: sender id is 0!");
		return;
	}
    IOHIDEventSystemClientDispatchEvent(ioSystemClient, event);
}

/*
Get sender id. If the device has not been rebooted, read senderid from file. Otherwise start set sender id callback
*/
void initSenderId()
{
    NSString *plistPath = [NSString stringWithFormat:@"%@/coreutils/touching/%@", getDocumentRoot(), TOUCH_SENDER_ID_PLIST_FILE_NAME];
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath])
    {
        // check start time
        NSInteger currentTime = [[NSDate date] timeIntervalSince1970];
        NSInteger timeSinceReboot = [NSProcessInfo processInfo].systemUptime;
        NSInteger thisRebootTime = currentTime - timeSinceReboot;
        NSLog(@"com.zjx.springboard: currentTime: %ld, time since reboot: %ld, last reboot time: %ld", currentTime, timeSinceReboot, thisRebootTime);
        
        NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        NSInteger lastRebootTime = [data[@"lastReboot"] longValue];
        
        if (abs(lastRebootTime - thisRebootTime) <= 3)
        {
            senderID = [data[@"senderID"] longLongValue];
            NSLog(@"com.zjx.springboard: since the device has not been rebooted. Read sender id from the file. SenderID get: %qX", senderID);
            return;
        }
    }
    
    NSLog(@"com.zjx.springboard: cannot read the sender id from file because the file doesn't exist or the device has restarted. Start set senderid callback.");
    startSetSenderIDCallBack();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // I know the code here is bad here, change this later.
        while (true)
        {
            [NSThread sleepForTimeInterval:2.0f];

            if (ioHIDEventSystemForSenderID != NULL && senderID != 0x0) // unregister the callback
            {
                IOHIDEventSystemClientUnregisterEventCallback(ioHIDEventSystemForSenderID);
                IOHIDEventSystemClientUnscheduleWithRunLoop(ioHIDEventSystemForSenderID, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                NSLog(@"com.zjx.springboard: unregister get sender id callback!");
                break;
            }
        }
    });

}


/*
Get the sender id and unregister itself.
*/
static void setSenderIdCallback(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    if (IOHIDEventGetType(event) == kIOHIDEventTypeDigitizer){
		if (senderID == 0x0)
        {
            NSError *err = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/coreutils/touching/", getDocumentRoot()] withIntermediateDirectories:YES attributes:nil error:&err];
            if (err)
            {
                NSLog(@"Cannot save senderid for future use, but the tweak should work fine. Error: %@", err);
            }

			senderID = IOHIDEventGetSenderID(event);

            NSInteger currentTime = [[NSDate date] timeIntervalSince1970];
            NSInteger timeSinceReboot = [NSProcessInfo processInfo].systemUptime;
            NSInteger rebootTime = currentTime - timeSinceReboot;

            NSDictionary *dict = @{@"lastReboot":@(rebootTime), @"senderID": @(senderID)};

            [dict writeToFile:[NSString stringWithFormat:@"%@/coreutils/touching/%@", getDocumentRoot(), TOUCH_SENDER_ID_PLIST_FILE_NAME] atomically: YES];

            NSLog(@"com.zjx.springboard: sender id is: %qX", senderID);
        }
    }
}

/**
Start the callback for setting sender id
*/
void startSetSenderIDCallBack()
{
    ioHIDEventSystemForSenderID = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientScheduleWithRunLoop(ioHIDEventSystemForSenderID, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientRegisterEventCallback(ioHIDEventSystemForSenderID, (IOHIDEventSystemClientEventCallback)setSenderIdCallback, NULL, NULL);
}

/*!!!!!!!!! Here, all the functions here will be moved to a class instance. This function is just for temporary use.*/
void initTouchGetScreenSize()
{
    device_screen_width = [Screen getScreenWidth];
    device_screen_height = [Screen getScreenHeight];
}
