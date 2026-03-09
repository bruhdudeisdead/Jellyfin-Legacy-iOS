//
//  Artwork.m
//  Jellyfin
//
//  Created by bruhdude on 7/12/25.
//  Copyright (c) 2025 bruhdude. All rights reserved.
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

+ (UIImage *)loadArtworkForId:(NSString *)itemId inContext:(NSManagedObjectContext *)context imageCache:(NSCache *)imageCache quality:(NSInteger)quality size:(CGSize)size completion:(void (^)(UIImage *image))completion {
    if (!itemId) return nil;

    UIImage *cachedImage = [imageCache objectForKey:itemId];
    if (cachedImage) {
        return cachedImage;
    }

    ArtworkCache *artwork = [self fetchArtworkForId:itemId inContext:context];
    if (artwork && artwork.imageData) {
        UIImage *image = [UIImage imageWithData:artwork.imageData];
        if (image) {
            [imageCache setObject:image forKey:itemId];
            return image;
        }
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
        NSMutableString *imageUrlString = [NSMutableString stringWithFormat:@"%@/Items/%@/Images/Primary?quality=%ld", serverUrl, itemId, (long)quality];
        if (size.width > 0 && size.height > 0) {
            [imageUrlString appendFormat:@"&width=%ld&height=%ld", (long)size.width, (long)size.height];
        }
        NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
        NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
        
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                [imageCache setObject:image forKey:itemId];
                
                [self saveArtworkInBackground:imageData forId:itemId mainContext:context completion:nil];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(image);
                });
            }
        }
    });
    
    return nil;
}

@end
