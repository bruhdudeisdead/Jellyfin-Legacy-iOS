//
//  ArtworkCache.h
//  Jellyfin
//
//  Created by bruhdude on 7/12/25.
//  Copyright (c) 2025 DumbStupidStuff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface ArtworkCache : NSManagedObject

@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSData * imageData;

@end
