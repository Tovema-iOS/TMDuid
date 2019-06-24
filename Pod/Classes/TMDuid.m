//
//  TMDuid.m
//  TMDuid
//
//  Created by luckysnow on 15-10-27.
//  Copyright (c) 2015年 luckysnow. All rights reserved.
//
#import "TMDuid.h"
#import "NdXDDeviceInfo.h"

@implementation TMDuid

+ (NSString *)duid
{
    return [NdXDDeviceInfo uniqueDeviceID];
}

@end
