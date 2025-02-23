//
//  NowPlayingViewController.h
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface NowPlayingViewController : UIViewController

@property (nonatomic, strong) NSURL *songURL;
@property (nonatomic, strong) UIImage *albumArt;
@property (nonatomic, strong) NSString *songTitle;
@property (nonatomic, strong) NSString *artistName;
@property (nonatomic, strong) NSString *albumName;
@property (nonatomic, assign) long long runtimeTicks;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *loopButton;
- (void)togglePlayPause;
@property (nonatomic, strong) NSArray *songList;
@property (nonatomic, assign) NSInteger currentIndex;

@end