//
//  EpisodeDetailViewController.h
//  Jellyfin
//
//  Created by bruhdude on 3/9/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EpisodeDetailViewController : UIViewController

@property (nonatomic, strong) NSDictionary *episode;
@property (nonatomic, strong) NSString *viewTitle;

@end
