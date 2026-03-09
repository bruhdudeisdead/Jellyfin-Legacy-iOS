//
//  SeasonsViewController.h
//  Jellyfin
//
//  Created by bruhdude on 3/9/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SeasonsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) NSString *showId;
@property (nonatomic, strong) NSString *viewTitle;

@end
