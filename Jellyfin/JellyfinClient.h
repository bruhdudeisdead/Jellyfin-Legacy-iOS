//
//  JellyfinClient.h
//  Jellyfin
//
//  Created by bruhdude on 3/7/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JellyfinClient : NSObject

+ (instancetype)sharedClient;

- (NSString *)deviceName;
- (NSString *)authHeader;
- (void)authenticateUserByName:(NSString *)username password:(NSString *)password completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getItemsWithParameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getItem:(NSString *)itemId completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getUser:(NSString *)userId completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getServerInfoWithCompletion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getSeasonsForShow:(NSString *)showId completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)getEpisodesForShow:(NSString *)showId seasonId:(NSString *)seasonId completion:(void (^)(NSDictionary *response, NSError *error))completion;

@end
