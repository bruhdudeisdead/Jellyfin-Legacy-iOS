//
//  Artwork.m
//  Jellyfin
//
//  Created by bruhdude on 7/12/25.
//  Copyright (c) 2025 DumbStupidStuff. All rights reserved.
//

#import "Artwork.h"

@implementation Artwork

+ (ArtworkCache *)fetchArtworkForId:(NSString *)id inContext:(NSManagedObjectContext *)context {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"ArtworkCache"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"id == %@", id];
    
    NSError *error = nil;
    NSArray *results = [context executeFetchRequest:fetchRequest error:&error];
    
    if (error) {
        NSLog(@"Error fetching artwork for %@: %@", id, error);
    }
    
    return results.firstObject;
}

+ (void)saveArtwork:(NSData *)imageData forId:(NSString *)id inContext:(NSManagedObjectContext *)context {
    ArtworkCache *cache = [NSEntityDescription insertNewObjectForEntityForName:@"ArtworkCache" inManagedObjectContext:context];
    cache.id = id;
    cache.imageData = imageData;
    
    NSError *error = nil;
    [context save:&error];
    if (error) {
        NSLog(@"Failed to save artwork for %@: %@", id, error);
    }
}

+ (void)saveArtworkInBackground:(NSData *)imageData forId:(NSString *)id mainContext:(NSManagedObjectContext *)mainContext completion:(void (^)(NSError *error))completion {
    
    NSManagedObjectContext *bgContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    bgContext.parentContext = mainContext;
    
    [bgContext performBlock:^{
        ArtworkCache *cache = [NSEntityDescription insertNewObjectForEntityForName:@"ArtworkCache"
                                                            inManagedObjectContext:bgContext];
        cache.id = id;
        cache.imageData = imageData;
        
        NSError *error = nil;
        if (![bgContext save:&error]) {
            NSLog(@"Error saving artwork in background: %@", error);
        }
        
        // Save parent context on main thread
        [mainContext performBlock:^{
            NSError *parentError = nil;
            if (![mainContext save:&parentError]) {
                NSLog(@"Error saving main context: %@", parentError);
            }
            if (completion) {
                completion(parentError);
            }
        }];
    }];
}


@end
