//
//  LibraryContentViewController.h
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LibraryContentViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *libraries;
@property (nonatomic, strong) NSString *libraryId;
@property (nonatomic, strong) NSString *viewTitle;

@end
