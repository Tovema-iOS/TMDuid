/*
 *  NdPhoneInfo.m
 *  NdComPlatform
 *
 *  Created by hiyo on 12-3-8.
 *  Copyright 2010 NetDragon WebSoft Inc.. All rights reserved.
 *
 */

#import "NdXDPhoneInfo.h"
#import "NdXDDeviceInfo.h"

#import <sys/types.h>
#import <sys/sysctl.h>

#define NDLOG NSLog
@implementation NdXDPhoneInfo

+ (NSString *)getHardwareTypeString
{
    static NSString *platform = nil;  //will not be released,just for cache
    if ([platform length] == 0) {
#if TARGET_IPHONE_SIMULATOR
        {
            CGRect bounds = [[UIScreen mainScreen] bounds];
            int width = (int)(bounds.size.width);
            int height = (int)(bounds.size.height);
            if ((width == 320) || (height == 320)) {
#ifdef __IPHONE_4_0
                float scale = [[UIScreen mainScreen] scale];
                if (scale == 2)
                    return @"iPhone3";
                return @"iPhone";
#else
                return @"iPhone";
#endif
            } else {
                return @"iPad";
            }
        }
#else
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        platform = [[NSString stringWithFormat:@"%s", machine] retain];  //say once again, will not be released
        free(machine);
#endif
    }
    return platform;
}

+ (NSString *)getCurrentDeviceType
{
#if TARGET_IPHONE_SIMULATOR && defined(__IPHONE_3_2) && (__IPHONE_3_2 <= __IPHONE_OS_VERSION_MAX_ALLOWED)
    CGSize sizePixel = [[UIScreen mainScreen] currentMode].size;
    CGFloat fMaxLength = MAX(sizePixel.width, sizePixel.height);

    if (fMaxLength > 960) {
        return @"ipad-simulator";
    } else if (fMaxLength > 480) {
        return @"iphone4-simulator";
    } else {
        return @"iphone-simulator";
    }
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunreachable-code"
    NSString *platform = [self getHardwareTypeString];
#pragma clang diagnostic pop
    return platform;
}

+ (NSString *)getChaosString:(NSString *)inputString
{
    if ([inputString length] <= 4)
        return nil;

    int length = (int)[inputString length];
    int count = length / 2 + length % 2;

    NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i++) {
        int pos = i * 2;
        int len = pos + 2 > length ? 1 : 2;

        NSString *str = [inputString substringWithRange:NSMakeRange(pos, len)];
        if (str)
            [arr addObject:str];
    }

    NSString *chaosInputString = @"";
    for (int i = 0; i < count - 1; i++) {
        int index = rand() % (count - 1);
        chaosInputString = [chaosInputString stringByAppendingString:[arr objectAtIndex:i]];
        chaosInputString = [chaosInputString stringByAppendingString:[arr objectAtIndex:index]];
    }
    chaosInputString = [chaosInputString stringByAppendingString:[arr lastObject]];
    [arr release];
    NDLOG(@"chaos output %@", chaosInputString);
    return chaosInputString;
}

+ (NSString *)getDeviceID
{
    return [NdXDDeviceInfo uniqueDeviceID];
}

+ (NSString *)getChaosDeviceID
{
    return [self getChaosString:[self getDeviceID]];
}

+ (CGRect)getScreenBounds
{
    return [[UIScreen mainScreen] bounds];
}

@end
