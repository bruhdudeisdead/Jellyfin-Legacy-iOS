#import "NowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#include <sys/sysctl.h>

@interface NowPlayingViewController ()

@property (nonatomic, strong) UIImageView *albumArtImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, assign) BOOL isLooping;
@property (nonatomic, assign) NSInteger currentTimeInMicroseconds;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation NowPlayingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
    }
    
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        NSLog(@"Error activating audio session: %@", error.localizedDescription);
    }
    
    [UIApplication sharedApplication].beginReceivingRemoteControlEvents;
    
    self.view.backgroundColor = [UIColor whiteColor];
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    backgroundImageView.image = self.albumArt;
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    backgroundImageView.clipsToBounds = YES;
    [self.view addSubview:backgroundImageView];
    
    UIToolbar *blurToolbar = [[UIToolbar alloc] initWithFrame:backgroundImageView.bounds];
    blurToolbar.barStyle = UIBarStyleBlack;
    blurToolbar.translucent = YES;
    [backgroundImageView addSubview:blurToolbar];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    NSLog(@"%lu", (unsigned long)UIViewAutoresizingFlexibleHeight);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    self.albumArtImageView = [[UIImageView alloc] initWithImage:self.albumArt];
    self.albumArtImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.albumArtImageView.frame = CGRectMake(20, 20, self.view.frame.size.width - 40, self.view.frame.size.width - 40);
    [self.scrollView addSubview:self.albumArtImageView];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.albumArtImageView.frame) + 10, self.view.frame.size.width - 40, 30)];
    self.titleLabel.text = self.songTitle ?: @"Unknown Song";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.scrollView addSubview:self.titleLabel];
    
    self.albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.titleLabel.frame) + 5, self.view.frame.size.width - 40, 20)];
    self.albumLabel.text = self.albumName ?: @"Unknown Album";
    self.albumLabel.textAlignment = NSTextAlignmentCenter;
    self.albumLabel.font = [UIFont systemFontOfSize:18];
    self.albumLabel.textColor = [UIColor whiteColor];
    [self.scrollView addSubview:self.albumLabel];
    
    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.albumLabel.frame) + 5, self.view.frame.size.width - 40, 20)];
    self.artistLabel.text = self.artistName ?: @"Unknown Artist";
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.font = [UIFont systemFontOfSize:16];
    self.artistLabel.textColor = [UIColor whiteColor];
    [self.scrollView addSubview:self.artistLabel];
    //ios <7 is EVIL!
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.albumLabel.backgroundColor = [UIColor clearColor];
    self.artistLabel.backgroundColor = [UIColor clearColor];
    self.tabBarController.tabBar.hidden = YES;
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    CGFloat toolbarHeight = tabBarFrame.size.height;
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:tabBarFrame];
    toolbar.barStyle = UIBarStyleBlackOpaque;
    toolbar.translucent = NO;
    
    UIBarButtonItem *playPauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayPause)];
    UIBarButtonItem *loopButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(toggleLoop)];
    UIBarButtonItem *skipBackwardButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(skipToPreviousSong)];
    UIBarButtonItem *skipForwardButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward target:self action:@selector(skipToNextSong)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    playPauseButton.tintColor = [UIColor whiteColor];
    loopButton.tintColor = [UIColor whiteColor];
    skipBackwardButton.tintColor = [UIColor whiteColor];
    skipForwardButton.tintColor = [UIColor whiteColor];
    
    toolbar.items = @[flexibleSpace, skipBackwardButton, flexibleSpace, playPauseButton, flexibleSpace, skipForwardButton, flexibleSpace, loopButton, flexibleSpace];
    
    self.toolbar = toolbar;
    
    self.audioPlayer = [AVPlayer playerWithURL:self.songURL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(songDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.audioPlayer.currentItem];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:[self albumArt]];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:@{
                                                                MPMediaItemPropertyArtwork: artwork,
                                                                MPMediaItemPropertyTitle: self.songTitle,
                                                                MPMediaItemPropertyArtist: self.artistName,
                                                                MPMediaItemPropertyAlbumTitle: self.albumName
                                                                }];
    self.currentTimeInMicroseconds = 0;
    
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 450);
    
    [self togglePlayPause];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat toolbarHeight = 50.0;
    CGFloat toolbarY = self.view.frame.size.height - self.tabBarController.tabBar.frame.size.height;
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    self.toolbar.frame = CGRectMake(0, toolbarY, self.view.frame.size.width, toolbarHeight);
}

- (void)togglePlayPause {
    NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
    UIBarButtonItem *playPauseItem = toolbarItems[3];
    
    if (self.audioPlayer.rate == 1.0) {
        [self.audioPlayer pause];
        [self updateNowPlayingInfo];
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayPause)];
    } else {
        [self updateNowPlayingInfo];
        [self.audioPlayer play];
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(togglePlayPause)];
    }
    playPauseItem.tintColor = [UIColor whiteColor];
    [toolbarItems replaceObjectAtIndex:3 withObject:playPauseItem];
    [self.toolbar setItems:toolbarItems animated:NO];
}

- (void)skipToNextSong {
    if (self.currentIndex + 1 < self.songList.count) {
        self.currentIndex++;
        [self updatePlayerWithCurrentSong];
    }
}

- (void)skipToPreviousSong {
    if (self.currentIndex > 0) {
        self.currentIndex--;
        [self updatePlayerWithCurrentSong];
    }
}

- (void)toggleLoop {
    self.isLooping = !self.isLooping;
    NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
    UIBarButtonItem *loopItem = toolbarItems[7];
    
    if (self.isLooping) {
        loopItem.tintColor = [UIColor blueColor];
    } else {
        loopItem.tintColor = [UIColor whiteColor];
    }
    
    [self.toolbar setItems:toolbarItems animated:NO];
}


- (void)songDidFinish:(NSNotification *)notification {
    if (self.currentIndex + 1 < self.songList.count) {
        self.currentIndex++;
        [self updatePlayerWithCurrentSong];
    } else {
        NSLog(@"End of playlist");
    }
}

- (void)updateNowPlayingInfo {
    NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
    nowPlayingInfo[MPMediaItemPropertyTitle] = self.songTitle;
    nowPlayingInfo[MPMediaItemPropertyArtist] = self.artistName;
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = self.albumName;
    
    if (self.albumArtImageView.image) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.albumArtImageView.image];
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork;
    }
    
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @(self.audioPlayer.rate);
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nowPlayingInfo];
}

- (void)updatePlayerWithCurrentSong {
    NSDictionary *currentSong = self.songList[self.currentIndex];
    NSString *songId = currentSong[@"Id"];
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *coverUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", serverUrl, songId];
    NSURL *coverUrl = [NSURL URLWithString:coverUrlString];
    NSURL *songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/Audio/%@/stream?static=true", serverUrl, songId]];
    
    self.songTitle = currentSong[@"Name"];
    self.artistName = currentSong[@"Artist"];
    self.albumName = currentSong[@"Album"];
    self.titleLabel.text = self.songTitle;
    self.artistLabel.text = self.artistName;
    self.albumLabel.text = self.albumName;
    self.songURL = songUrl;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:coverUrl];
        UIImage *coverImage = imageData ? [UIImage imageWithData:imageData] : [UIImage imageNamed:@"placeholder"];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.albumArtImageView.image = coverImage;
            AVPlayerItem *nextItem = [AVPlayerItem playerItemWithURL:songUrl];
            [self.audioPlayer replaceCurrentItemWithPlayerItem:nextItem];
            [self.audioPlayer play];
            [self updateNowPlayingInfo];
        });
    });
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPlay:
                [self togglePlayPause];
                break;
            case UIEventSubtypeRemoteControlPause:
                [self togglePlayPause];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [self togglePlayPause];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                [self skipToNextSong];
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                [self skipToPreviousSong];
                break;
            default:
                break;
        }
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.tabBar.hidden = YES;
    [self.view addSubview:self.toolbar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.tabBarController.tabBar.hidden = NO;
    if (self.audioPlayer) {
        [self.audioPlayer pause];
        NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
        UIBarButtonItem *playPauseItem = toolbarItems[1];
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayPause)];
        playPauseItem.tintColor = [UIColor whiteColor];
        [toolbarItems replaceObjectAtIndex:1 withObject:playPauseItem];
        [self.toolbar setItems:toolbarItems animated:NO];
    }
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}
@end
