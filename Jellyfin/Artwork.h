//
//  Artwork.h
//  Jellyfin
//
//  Created by bruhdude on 7/12/25.
//  Copyright (c) 2025 DumbStupidStuff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "ArtworkCache.h"

@class ArtworkCache;

@interface Artwork : NSObject

+ (ArtworkCache *)fetchArtworkForId:(NSString *)id inContext:(NSManagedObjectContext *)context;
+ (void)saveArtwork:(NSData *)imageData forId:(NSString *)id inContext:(NSManagedObjectContext *)context;
+ (void)saveArtworkInBackground:(NSData *)imageData forId:(NSString *)id mainContext:(NSManagedObjectContext *)mainContext completion:(void (^)(NSError *error))completion;

@end
