//
//  NdCPDeviceInfo.m
//  NdComPlatformFoundation
//
//  Created by BeiQi56 on 13-10-21.
//  Copyright (c) 2013年 NdCP. All rights reserved.
//

#import "NdXDDeviceInfo.h"
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AdSupport/AdSupport.h>
#import "NdUDID_Define.h"

#if IS_FOR_JAIL_BREAK
#include <dlfcn.h>
#define READ_MAC_WITH_UNIX_API
#else
#import "NdXDKeychainItemWrapper.h"
#endif  //IS_FOR_JAIL_BREAK

#ifdef READ_MAC_WITH_UNIX_API
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#endif  //READ_MAC_WITH_UNIX_API


static NSString *s_udid = nil;
static NSString *s_mac = nil;

static NSString *s_keychain_accessgroup = nil;
static NSString *s_keychain_identifier = @"uuid_by_ndcomplatform_v2.0";
static NSString *s_old_keychain_identifier = @"uuid_by_ndcomplatform";
static NSString *s_backup_udid_key = @"uuid_backup_key";
static CFTypeRef *s_keychain_accessible = NULL;

#define NDCP_SET_STATIC_VALUE(var, value) \
    do {                                  \
        [value retain];                   \
        [var release];                    \
        var = value;                      \
    } while (0);


@implementation NdXDDeviceInfo

+ (BOOL)iOSVersionGE7
{
    return [[[UIDevice currentDevice] systemVersion] intValue] >= 7 ? YES : NO;
}

+ (NSString *)uniqueDeviceID
{
    if (nil == s_udid) {
#if IS_FOR_JAIL_BREAK
        if ([self iOSVersionGE7]) {
            [self loadDeviceInfoFromMobileGestaltDylib];
        } else {
            [self loadUniqueIdFromUIDeviceAPI];
        }
#endif  //IS_FOR_JAIL_BREAK


        if ([s_udid length] <= 0) {
            [self loadDeviceIdForAdvertising];
            if ([s_udid length] <= 0) {
                [self loadDeviceIdWithOptionScheme];
            }
        }

        if (nil == s_udid) {
            NDCP_SET_STATIC_VALUE(s_udid, @"");
        }
    }
    return s_udid;
}

+ (NSString *)macAddress
{
    if (nil == s_mac) {
        if ([self iOSVersionGE7]) {
#if IS_FOR_JAIL_BREAK
            [self loadDeviceInfoFromMobileGestaltDylib];
#else
            //非越狱的，iOS7+版本，mac设为空
#endif  //IS_FOR_JAIL_BREAK

        } else {
#ifdef READ_MAC_WITH_UNIX_API
            [self loadMacAddressWithUnixAPI];
#endif  //READ_MAC_WITH_UNIX_API
        }

        if (nil == s_mac) {
            NDCP_SET_STATIC_VALUE(s_mac, @"");
        }
    }

    return s_mac;
}

#pragma mark - Advertisement id (iOS6+)
+ (NSString *)identifierForAdvertising
{
#if 0
    if (NSClassFromString(@"ASIdentifierManager") != nil) {
        return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    }
    else {
        return nil;
    }
#else
    //appstore do not allowed app use advertisingIdentifier if the app do not use iad
    return nil;
#endif
}

+ (void)loadDeviceIdForAdvertising
{
    NSString *udid = [self identifierForAdvertising];
    NDCP_SET_STATIC_VALUE(s_udid, udid);
}


#if IS_FOR_JAIL_BREAK

#pragma mark - UDID (<iOS7)
+ (void)loadUniqueIdFromUIDeviceAPI
{
    UIDevice *device = [UIDevice currentDevice];
    SEL selSysUdid = @selector(uniqueIdentifier);
    if ([device respondsToSelector:selSysUdid]) {
        NSString *udid = [device performSelector:selSysUdid withObject:nil];
        NDCP_SET_STATIC_VALUE(s_udid, udid);
    }
}

#pragma mark - UDID (iOS7+)
+ (void)loadDeviceInfoFromMobileGestaltDylib
{
#define DYNAMIC_LOAD 1
#if DYNAMIC_LOAD
    void *handle = dlopen("libMobileGestalt.dylib", RTLD_LAZY);
    if (handle) {
        typedef CFPropertyListRef (*MGCopyAnswer)(CFStringRef property);
        MGCopyAnswer fCpAnswer = (MGCopyAnswer)dlsym(handle, "MGCopyAnswer");
#else  //DYNAMIC_LOAD
    extern CFPropertyListRef MGCopyAnswer(CFStringRef property);
    CFPropertyListRef (*fCpAnswer)(CFStringRef property) = MGCopyAnswer;
#endif  //DYNAMIC_LOAD
        if (fCpAnswer) {
            NSString *strUdid = (NSString *)fCpAnswer(CFSTR("UniqueDeviceID"));
            if ([strUdid length] > 0 && [s_udid length] <= 0) {
                NDCP_SET_STATIC_VALUE(s_udid, strUdid);
            }

            NSString *strWifi = (NSString *)fCpAnswer(CFSTR("WifiAddress"));
            NSString *strMac = [self ndcpMacAddressFromWifiAddress:strWifi];
            if ([strMac length] > 0 && [s_mac length] <= 0) {
                NDCP_SET_STATIC_VALUE(s_mac, strMac);
            }
            NSLog(@"udid = %@, mac = %@", strUdid, strMac);
        }
#if DYNAMIC_LOAD
        dlclose(handle);
        handle = NULL;
    }
#endif  //DYNAMIC_LOAD
}

+ (NSString *)ndcpMacAddressFromWifiAddress:(NSString *)wifiAddress
{
    NSString *str = [wifiAddress stringByReplacingOccurrencesOfString:@":" withString:@""];
    return [str uppercaseString];
}

#endif  //IS_FOR_JAIL_BREAK


#ifdef READ_MAC_WITH_UNIX_API

#pragma mark - Mac address (Unix API)
+ (void)loadMacAddressWithUnixAPI
{
    NSString *mac = [self macAddressWithUnixAPI];
    NDCP_SET_STATIC_VALUE(s_mac, mac);
}

+ (NSString *)macAddressWithUnixAPI
{
    int mib[6];
    size_t len;
    char *buf;
    unsigned char *ptr;
    struct if_msghdr *ifm;
    struct sockaddr_dl *sdl;

    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;

    if ((mib[5] = if_nametoindex("en0")) == 0) {
        NSLog(@"%@", @"macAddress Error: if_nametoindex error\n");
        return nil;
    }

    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        NSLog(@"%@", @"macAddress Error: sysctl, take 1\n");
        return nil;
    }

    if ((buf = malloc(len)) == NULL) {
        NSLog(@"%@", @"macAddress Error: Could not allocate memory. error!\n");
        return nil;
    }

    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        NSLog(@"%@", @"macAddress Error: sysctl, take 2");
        free(buf);
        buf = NULL;
        return nil;
    }

    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);

    NSString *outstring = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X",
                                                     *ptr,
                                                     *(ptr + 1),
                                                     *(ptr + 2),
                                                     *(ptr + 3),
                                                     *(ptr + 4),
                                                     *(ptr + 5)];
    free(buf);

    return outstring;
}

#endif  //READ_MAC_WITH_UNIX_API


#if IS_FOR_JAIL_BREAK

#pragma mark - 取不到udid的备选方案 (jail break)
+ (void)loadDeviceIdWithOptionScheme
{
    NSString *optionId = [self getDeviceWifiAddress_Encapsulation];
    if ([optionId length] <= 0) {
        optionId = [self getDeviceUUID_Encapsulation];
    }
    NDCP_SET_STATIC_VALUE(s_udid, optionId);
}

typedef enum {
    eNdCP_devID_NORMAL = 0,
    eNdCP_devID_WIFI = 1,
    eNdCP_devID_UUID = 2,
} ENDCP_DEVICE_ID_TYPE;
#define TQ_NEW_UUID_KEY @"uuid_created_by_developer"

+ (NSString *)getDeviceWifiAddress_Encapsulation
{
    NSString *strAddress = [self macAddress];
    return [self TQformatStringForSrcId:strAddress withType:eNdCP_devID_WIFI];
}

+ (NSString *)getDeviceUUID_Encapsulation
{
    NSString *strUUID = [[NSUserDefaults standardUserDefaults] objectForKey:TQ_NEW_UUID_KEY];
    if ([strUUID length] <= 0) {
        strUUID = [self randomUUID];
        [[NSUserDefaults standardUserDefaults] setObject:strUUID forKey:TQ_NEW_UUID_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    return [self TQformatStringForSrcId:strUUID withType:eNdCP_devID_UUID];
}

+ (NSString *)randomUUID
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);

    NSString *result = [NSString stringWithFormat:@"%@", uuidStr];

    CFRelease(uuidStr);
    CFRelease(uuid);

    return result;
}

+ (NSString *)TQformatStringForSrcId:(NSString *)strId withType:(ENDCP_DEVICE_ID_TYPE)type
{
    if ([strId length] <= 0)
        return strId;

    NSString *strResult = strId;
    switch (type) {
        case eNdCP_devID_WIFI:
        case eNdCP_devID_UUID:
            strResult = [NSString stringWithFormat:@"%02d%@", type, [NdXDBaseFunc encodeBase64WithString:strId]];
            break;
        default:
            break;
    }
    return strResult;
}


#else  //IS_FOR_JAIL_BREAK


#pragma mark - 取不到udid的备选方案 (app store)

+ (void)loadDeviceIdWithOptionScheme
{
    NdXDKeychainItemWrapper *wrapper = [[[NdXDKeychainItemWrapper alloc] initWithIdentifier:s_keychain_identifier accessGroup:[self keychainAccessGroup] accessible:[self keychainAccessible]] autorelease];
    id data = [wrapper objectForKey:(id)kSecValueData];
    if ([data isKindOfClass:[NSString class]] == NO) {
        NSLog(@"wrong uuid type data %@ found..", data);
        [wrapper resetKeychainItem];
        data = nil;
    }

    NSString *optionId = (NSString *)data;

    //    if ([optionId length] == 0)
    //    {
    //        NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    //
    //        if(!idfa || [idfa isEqualToString:@""])
    //        {
    //            CFUUIDRef uuid = CFUUIDCreate(NULL);
    //
    //
    //            idfa = (NSString *) CFUUIDCreateString(NULL, uuid);
    //             NDCP_SET_STATIC_VALUE(s_udid, idfa);
    //            CFRelease(uuid);
    //        }
    //
    //        return;
    //    }


    if ([optionId length] == 0) {
        //检查是否有旧的数据
        NSMutableDictionary *oldKeychainData = [wrapper oldKeychainDataForIdentifier:s_old_keychain_identifier group:[self keychainAccessGroup]];
        NSString *oldOptionId = nil;
        if (oldKeychainData) {
            id oldData = [oldKeychainData objectForKey:(id)kSecValueData];
            if ([oldData isKindOfClass:[NSString class]]) {
                oldOptionId = (NSString *)oldData;
            }
        }

        if (oldOptionId == nil) {
            [wrapper cleanKeychain];
            if ([self isKeychainCachedToLocal]) {
                optionId = [[NSUserDefaults standardUserDefaults] valueForKey:s_backup_udid_key];
            }
        } else {
            optionId = oldOptionId;
        }

        if ([optionId length] == 0) {
            CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
            CFStringRef cfUUIDStr = CFUUIDCreateString(NULL, theUUID);
            optionId = [NSString stringWithString:(NSString *)cfUUIDStr];
            CFRelease(theUUID);
            CFRelease(cfUUIDStr);
        }

        if ([optionId length] != 0) {
            [wrapper setObject:optionId forKey:(id)kSecValueData];
        }
        NSLog(@"uuid %@ in analyze", optionId);
    }

    if ([optionId length] != 0 && [self isKeychainCachedToLocal]) {
        [[NSUserDefaults standardUserDefaults] setValue:optionId forKey:s_backup_udid_key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    //    NSLog(@"load uuid from keychain %@", optionId);
    NDCP_SET_STATIC_VALUE(s_udid, optionId);
}

#endif  //IS_FOR_JAIL_BREAK

+ (void)setKeychainAccessGroup:(NSString *)accessGroup
{
    NDCP_SET_STATIC_VALUE(s_keychain_accessgroup, accessGroup);
}

+ (NSString *)keychainAccessGroup
{
    return s_keychain_accessgroup;
}

+ (void)setKeychainAccessible:(CFTypeRef)accessible
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreceiver-expr"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
    NDCP_SET_STATIC_VALUE(s_keychain_accessible, accessible);
#pragma clang diagnostic pop
}

+ (CFTypeRef)keychainAccessible
{
    return s_keychain_accessible;
}

static BOOL s_CacheToLocal = YES;  //wk default use userdefault

+ (void)setKeychainCachedToLocal:(BOOL)cache
{
    s_CacheToLocal = cache;
}

+ (BOOL)isKeychainCachedToLocal
{
    return s_CacheToLocal;
}

+ (void)setIMEI:(NSString *)imei
{
    if ([s_udid length] == 0 && [imei length] != 0) {
        NDCP_SET_STATIC_VALUE(s_udid, imei);
    }
}

@end
