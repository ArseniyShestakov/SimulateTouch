#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include "Record.h"
#include "Common.h"
#include "Config.h"
#include "AlertBox.h"
#include "Process.h"
#include "Screen.h"
#include "Window.h"
#include "SocketServer.h"

CFRunLoopRef recordRunLoop = NULL;
static Boolean isRecording = false;
extern NSString *documentPath;
static NSFileHandle *scriptRecordingFileHandle = NULL;
static IOHIDEventSystemClientRef ioHIDEventSystemForRecording = NULL;
static CFAbsoluteTime lastEventTimeStampForRecording;

static CGFloat device_screen_width = 0;
static CGFloat device_screen_height = 0;

UIWindow *_recordIndicator;


void startRecording(CFWriteStreamRef requestClient, NSError **error)
{
   if (isRecording)
    {
        NSLog(@"com.zjx.springboard: recording has already started.");
        *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp" code:999 userInfo:@{NSLocalizedDescriptionKey:@"-1;;Recording has already started.\r\n"}];
        return;
    }

    // get the screen size
    device_screen_width = [Screen getScreenWidth];
    device_screen_height = [Screen getScreenHeight];

    if (device_screen_width == 0 || device_screen_width == 0)
    {
        *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp" code:999 userInfo:@{NSLocalizedDescriptionKey:@"-1;;Unable to start recording. Cannot get screen size.\r\n"}];
        showAlertBox(@"Error", @"Unable to start recording. Cannot get screen size.", 999);
        return;
    }
    
    NSError *err = nil;

    // get current time, we use time as the name of the script package
    NSDate * now = [NSDate date];
    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    [outputFormatter setDateFormat:@"yyMMddHHmmss"];
    NSString *currentDateTime = [outputFormatter stringFromDate:now];

    
    // generate the script directory
    NSString *scriptDirectory = [NSString stringWithFormat:@"%@/" RECORDING_FILE_FOLDER_NAME "/%@.bdl", getScriptsFolder(), currentDateTime];
    [[NSFileManager defaultManager] createDirectoryAtPath:scriptDirectory withIntermediateDirectories:YES attributes:nil error:&err];
    
    if (err)
    {
        NSLog(@"com.zjx.springboard: create script recording folder error. Error: %@", err);
        *error = [NSError errorWithDomain:@"com.zjx.zxtouchsp" code:999 userInfo:@{NSLocalizedDescriptionKey:@"-1;;Create script recording folder error.\r\n"}];
        showAlertBox(@"Error", [NSString stringWithFormat:@"Cannot create script. Error info: %@", err], 999);
        return;
    }

    // get basic info of current device 
    NSMutableDictionary *infoDict = [NSMutableDictionary dictionary];
    [infoDict setObject:[NSString stringWithFormat:@"%@.raw", currentDateTime] forKey:@"Entry"];

    // orientation
    int orientation = [Screen getScreenOrientation];
    [infoDict setObject:[@(orientation) stringValue] forKey:@"Orientation"];

    // front most application
    SBApplication *frontMostApp = getFrontMostApplication();

    if (frontMostApp == nil)
    {
        //NSLog(@"com.zjx.springboard: foreground is springboard");
        [infoDict setObject:@"com.apple.springboard" forKey:@"FrontApp"];
    }
    else
    {
        NSLog(@"com.zjx.springboard: bundle identifier of front most application: %@", frontMostApp);
        [infoDict setObject:frontMostApp.bundleIdentifier forKey:@"FrontApp"]; //[frontMostApp displayIdentifier]
    }

    // write to plist file in script directory
    [infoDict writeToFile:[NSString stringWithFormat:@"%@/info.plist", scriptDirectory, currentDateTime] atomically:YES];


    // generate a raw file for writing
    NSString *rawFilePath = [NSString stringWithFormat:@"%@/%@.raw", scriptDirectory, currentDateTime];
    [[NSFileManager defaultManager] createFileAtPath:rawFilePath contents:nil attributes:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // start recording
        NSLog(@"com.zjx.springboard: start recording.");
        
        notifyClient((UInt8*)[scriptDirectory UTF8String], requestClient);

        isRecording = true;

        // show indicator
        dispatch_async(dispatch_get_main_queue(), ^{
            _recordIndicator = [[UIWindow alloc] initWithFrame:CGRectMake(0,0,10*2,10*2)];
            _recordIndicator.windowLevel = UIWindowLevelStatusBar;
            _recordIndicator.hidden = NO;
            [_recordIndicator setBackgroundColor:[UIColor clearColor]];
            [_recordIndicator setUserInteractionEnabled:NO];

            UIView *circleView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10*2,10*2)];

            //circleView.alpha = 1;
            circleView.layer.cornerRadius = 10;  // half the width/height
            circleView.backgroundColor = [UIColor redColor];
            [_recordIndicator addSubview:circleView];
        });

        scriptRecordingFileHandle = [NSFileHandle fileHandleForWritingAtPath:rawFilePath];

        // get time stamp
        lastEventTimeStampForRecording = CFAbsoluteTimeGetCurrent();

        // start watching function
        ioHIDEventSystemForRecording = IOHIDEventSystemClientCreate(kCFAllocatorDefault);

        IOHIDEventSystemClientScheduleWithRunLoop(ioHIDEventSystemForRecording, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDEventSystemClientRegisterEventCallback(ioHIDEventSystemForRecording, (IOHIDEventSystemClientEventCallback)recordIOHIDEventCallback, NULL, NULL);
        
        
        recordRunLoop = CFRunLoopGetCurrent();
        CFRunLoopRun();
    });
}

//TODO: multi-touch support! get touch index automatically, rather than set to 7.
static void recordIOHIDEventCallback(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef parentEvent) 
{
    //NSLog(@"### com.zjx.springboard: handle_event : %d", IOHIDEventGetType(event));
    if (!scriptRecordingFileHandle)
    {
        isRecording = false;

        showAlertBox(@"Error", @"Unknown error while recording script. Recording is now stopping. Error code: 31.", 999);
        return;
    }
    if (IOHIDEventGetType(parentEvent) == kIOHIDEventTypeDigitizer)
    {
        NSArray *childrens = (__bridge NSArray *)IOHIDEventGetChildren(parentEvent);

        for (int i = 0; i < [childrens count]; i++)
        {
            Boolean print = false;
            IOHIDEventRef event = (__bridge IOHIDEventRef)childrens[i];
            IOHIDFloat x = IOHIDEventGetFloatValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerX);
            IOHIDFloat y = IOHIDEventGetFloatValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerY);
            int eventMask = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerEventMask);
            int range = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerRange);
            int touch = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerTouch);
            int index = IOHIDEventGetIntegerValue(event, (IOHIDEventField)kIOHIDEventFieldDigitizerIndex);
            //NSLog(@"### com.zjx.springboard: x %f : y %f. eventMask: %d. index: %d, range: %d. Touch: %d", x, y, eventMask, index, range, touch);
            //NSLog(@"### com.zjx.springboard:  x %f : y %f. eventMask: %d. index: %d, range: %d. Touch: %d.", x, y, eventMask, index, range, touch);
            float sleepusecs = (CFAbsoluteTimeGetCurrent() - lastEventTimeStampForRecording)*1000000;
            float xToWrite =  x*device_screen_width*10;
            float yToWrite =  y*device_screen_height*10;

            if ( touch == 1 && eventMask & 2 )
            {
                // touch down
                //NSLog(@"com.zjx.springboard: Touch down. x %f : y %f. index: %d.  eventmask: %d, range: %d, touch: %d", x*device_screen_width, y*device_screen_height, index, eventMask, range, touch);
                [scriptRecordingFileHandle writeData:[[NSString stringWithFormat:@"18%.0f\n1011%02d%05.0f%05.0f\n", sleepusecs, index, xToWrite, yToWrite] dataUsingEncoding:NSUTF8StringEncoding]];
                lastEventTimeStampForRecording = CFAbsoluteTimeGetCurrent();
                print = true;
            }
            else if ( touch == 1 && eventMask & 4 )
            {
                // touch move
                //NSLog(@"com.zjx.springboard: touch moved to (%f, %f). index: %d. eventmask: %d, range: %d, touch: %d", x*device_screen_width, y*device_screen_height, index, eventMask, range, touch);
                [scriptRecordingFileHandle writeData:[[NSString stringWithFormat:@"18%.0f\n1012%02d%05.0f%05.0f\n", sleepusecs, index, xToWrite, yToWrite] dataUsingEncoding:NSUTF8StringEncoding]];
                lastEventTimeStampForRecording = CFAbsoluteTimeGetCurrent();
                print = true;
            }
            else if (!touch && (eventMask & 2) )
            {
                // touch up
                //NSLog(@"com.zjx.springboard: Touch up. x %f : y %f. index: %d.  eventmask: %d, range: %d, touch: %d", x*device_screen_width, y*device_screen_height, index, eventMask, range, touch);
                [scriptRecordingFileHandle writeData:[[NSString stringWithFormat:@"18%.0f\n1010%02d%05.0f%05.0f\n", sleepusecs, index, xToWrite, yToWrite] dataUsingEncoding:NSUTF8StringEncoding]];
                lastEventTimeStampForRecording = CFAbsoluteTimeGetCurrent();
                print = true;
            }
        }
        /*
		if (senderID == 0)
			senderID = IOHIDEventGetSenderID(event);
        */


        
        
    }
    else if (IOHIDEventGetType(parentEvent) == kIOHIDEventTypeButton)
    {
        NSLog(@"### com.zjx.springboard: type: button, senderID: %qX", IOHIDEventGetType(parentEvent), IOHIDEventGetSenderID(parentEvent));
    }
}

void stopRecording()
{
    NSLog(@"com.zjx.springboard: stop recording.");

    // remove indicator
    dispatch_async(dispatch_get_main_queue(), ^{
        _recordIndicator.hidden = YES;
        _recordIndicator = nil;
    });

    
    if (ioHIDEventSystemForRecording)
    {
        IOHIDEventSystemClientUnregisterEventCallback(ioHIDEventSystemForRecording);
        IOHIDEventSystemClientUnscheduleWithRunLoop(ioHIDEventSystemForRecording, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

        ioHIDEventSystemForRecording = NULL;
    }

    if (scriptRecordingFileHandle)
    {
        [scriptRecordingFileHandle synchronizeFile];
        [scriptRecordingFileHandle closeFile];

        scriptRecordingFileHandle = nil;
    }
    if (recordRunLoop)
    {
        CFRunLoopStop(recordRunLoop);
        recordRunLoop = NULL;
    }

    //set this at last
    isRecording = false;
}

Boolean isRecordingStart()
{
    return isRecording;
}
