//
//  JellyfinClient.m
//  Jellyfin
//
//  Created by bruhdude on 3/7/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "JellyfinClient.h"
#include <sys/sysctl.h>

@implementation JellyfinClient

+ (instancetype)sharedClient {
    static JellyfinClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[JellyfinClient alloc] init];
    });
    return sharedClient;
}

- (NSString *)deviceModelIdentifier {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *identifier = [NSString stringWithUTF8String:machine];
    free(machine);
    return identifier;
}

- (NSString *)deviceName {
    NSString *modelIdentifier = [self deviceModelIdentifier];
    NSDictionary *modelMapping = @{
                                   //scary
                                   @"x86_64": @"Xcode Simulator",
                                   //iphone
                                   @"iPhone2,1": @"iPhone 3GS",
                                   @"iPhone3,1": @"iPhone 4",
                                   @"iPhone3,2": @"iPhone 4",
                                   @"iPhone3,3": @"iPhone 4",
                                   @"iPhone4,1": @"iPhone 4S",
                                   @"iPhone5,1": @"iPhone 5",
                                   @"iPhone5,2": @"iPhone 5",
                                   @"iPhone5,3": @"iPhone 5c",
                                   @"iPhone5,4": @"iPhone 5c",
                                   @"iPhone6,1": @"iPhone 5s",
                                   @"iPhone6,2": @"iPhone 5s",
                                   @"iPhone7,1": @"iPhone 6 Plus",
                                   @"iPhone7,2": @"iPhone 6",
                                   // no iphone 6s and later, screw you
                                   //ipad
                                   @"iPad2,1": @"iPad 2",
                                   @"iPad2,2": @"iPad 2",
                                   @"iPad2,3": @"iPad 2",
                                   @"iPad2,4": @"iPad 2",
                                   @"iPad3,1": @"iPad 3",
                                   @"iPad3,2": @"iPad 3",
                                   @"iPad3,3": @"iPad 3",
                                   @"iPad3,4": @"iPad 4",
                                   @"iPad3,5": @"iPad 4",
                                   @"iPad3,6": @"iPad 4",
                                   @"iPad2,5": @"iPad mini",
                                   @"iPad2,6": @"iPad mini",
                                   @"iPad2,7": @"iPad mini",
                                   @"iPad4,1": @"iPad Air",
                                   @"iPad4,2": @"iPad Air",
                                   @"iPad4,4": @"iPad mini 2",
                                   @"iPad4,5": @"iPad mini 2",
                                   @"iPad5,3": @"iPad Air 2",
                                   @"iPad5,4": @"iPad Air 2",
                                   @"iPad4,7": @"iPad mini 3",
                                   @"iPad4,8": @"iPad mini 3",
                                   // no later, screw you
                                   //ipod touch
                                   @"iPod4,1": @"iPod touch (4th generation)",
                                   @"iPod5,1": @"iPod touch (5th generation)",
                                   @"iPod7,1": @"iPod touch (6th generation)",
                                   //s
                                   };
    
    NSString *friendlyName = modelMapping[modelIdentifier];
    return friendlyName ?: modelIdentifier;
}

- (NSString *)authHeader {
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    if (!token) return nil;
    
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    return [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
}

- (void)authenticateUserByName:(NSString *)username password:(NSString *)password completion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    if (!serverUrl) {
        if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Users/AuthenticateByName", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\"", deviceName, (long)deviceId];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{@"Username": username, @"Pw": password};
    NSError *jsonError;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    request.HTTPBody = bodyData;
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   if (completion) completion(nil, connectionError);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (completion) completion(jsonResponse, jsonError);
                               }
                           }];
}

- (NSURL *)baseURL {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    return [NSURL URLWithString:serverUrl];
}

- (void)getItemsWithParameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    if (!serverUrl) {
        if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
        return;
    }
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@/Items?", serverUrl];
    
    NSMutableArray *paramStrings = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        NSString *value = [NSString stringWithFormat:@"%@", obj];
        NSString *encodedValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                       NULL,
                                                                                                       (CFStringRef)value,
                                                                                                       NULL,
                                                                                                       (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                       kCFStringEncodingUTF8 ));
        [paramStrings addObject:[NSString stringWithFormat:@"%@=%@", key, encodedValue]];
    }];
    
    [urlString appendString:[paramStrings componentsJoinedByString:@"&"]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"[JellyfinClient] Requesting URL: %@", url);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[self authHeader] forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   if (completion) completion(nil, connectionError);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (completion) completion(jsonResponse, jsonError);
                               }
                           }];
}

- (void)getItem:(NSString *)itemId completion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    if (!serverUrl) {
        if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Items/%@", serverUrl, itemId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[self authHeader] forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   if (completion) completion(nil, connectionError);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (completion) completion(jsonResponse, jsonError);
                               }
                           }];
}

- (void)getUser:(NSString *)userId completion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    if (!serverUrl) {
        if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Users/%@", serverUrl, userId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[self authHeader] forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   if (completion) completion(nil, connectionError);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (completion) completion(jsonResponse, jsonError);
                               }
                           }];
}

- (void)getServerInfoWithCompletion:(void (^)(NSDictionary *response, NSError *error))completion {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *urlString = [NSString stringWithFormat:@"%@/System/Info/Public", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   if (completion) completion(nil, connectionError);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (completion) completion(jsonResponse, jsonError);
                               }
                                                      }];
                           }
                           
                           - (void)getSeasonsForShow:(NSString *)showId completion:(void (^)(NSDictionary *response, NSError *error))completion {
                               NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
                               if (!serverUrl) {
                                   if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
                                   return;
                               }
                               
                               NSString *urlString = [NSString stringWithFormat:@"%@/Shows/%@/Seasons", serverUrl, showId];
                               NSURL *url = [NSURL URLWithString:urlString];
                               
                               NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                               [request setValue:[self authHeader] forHTTPHeaderField:@"Authorization"];
                               
                               [NSURLConnection sendAsynchronousRequest:request
                                                                  queue:[NSOperationQueue mainQueue]
                                                      completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                                          if (connectionError) {
                                                              if (completion) completion(nil, connectionError);
                                                              return;
                                                          }
                                                          
                                                          if (data) {
                                                              NSError *jsonError = nil;
                                                              NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                                              if (completion) completion(jsonResponse, jsonError);
                                                          }
                                                      }];
                           }
                           
                           - (void)getEpisodesForShow:(NSString *)showId seasonId:(NSString *)seasonId completion:(void (^)(NSDictionary *response, NSError *error))completion {
                               NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
                               if (!serverUrl) {
                                   if (completion) completion(nil, [NSError errorWithDomain:@"JellyfinClient" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Server URL not set"}]);
                                   return;
                               }
                               
                               NSString *urlString = [NSString stringWithFormat:@"%@/Shows/%@/Episodes%@", serverUrl, showId, seasonId ? [NSString stringWithFormat:@"?seasonId=%@&Fields=Overview", seasonId] : @"?Fields=Overview"];
                               NSURL *url = [NSURL URLWithString:urlString];
                               
                               NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                               [request setValue:[self authHeader] forHTTPHeaderField:@"Authorization"];
                               
                               [NSURLConnection sendAsynchronousRequest:request
                                                                  queue:[NSOperationQueue mainQueue]
                                                      completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                                          if (connectionError) {
                                                              if (completion) completion(nil, connectionError);
                                                              return;
                                                          }
                                                          
                                                          if (data) {
                                                              NSError *jsonError = nil;
                                                              NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                                              if (completion) completion(jsonResponse, jsonError);
                                                          }
                                                      }];
                           }
                           
                           @end
                           