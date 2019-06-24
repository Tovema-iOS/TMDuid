/*
 *  NdPhoneInfo.h
 *  NdComPlatform
 *
 *  Created by hiyo on 12-3-8.
 *  Copyright 2010 NetDragon WebSoft Inc.. All rights reserved.
 *
 */
#import <UIKit/UIKit.h>


@interface NdXDPhoneInfo : NSObject
{
}

//get the type of device
+ (NSString *)getCurrentDeviceType;

//get phone device id
+ (NSString *)getDeviceID;

//get chaos device id
+ (NSString *)getChaosDeviceID;

//get the main screen bounds
+ (CGRect)getScreenBounds;

@end
