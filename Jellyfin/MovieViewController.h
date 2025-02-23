//
//  MovieViewController.h
//  Jellyfin
//
//  Created by Jack on 2/22/25.
//  Copyright (c) 2025 DumbStupidStuff. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MovieViewController : UIViewController

@property (nonatomic, strong) UIImage *moviePoster;
@property (nonatomic, strong) NSString *movieId;
@property (nonatomic, strong) NSString *movieTitle;
@property (nonatomic, strong) NSString *movieTagline;
@property (nonatomic, strong) NSString *movieProductionYear;
@property (nonatomic, strong) NSString *movieOverview;

@end
