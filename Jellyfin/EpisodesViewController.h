//
//  EpisodesViewController.h
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EpisodesViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSString *showId;
@property (nonatomic, strong) NSString *seasonId;
@property (nonatomic, strong) NSString *viewTitle;

@end
