#import "NowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#include <sys/sysctl.h>

@interface NowPlayingViewController ()

@property (nonatomic, strong) UIImageView *albumArtImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UISlider *seekSlider;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, assign) BOOL isLooping;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, assign) BOOL isViewVisible;

@end

@implementation NowPlayingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.isViewVisible = YES;
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
    }
    
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        NSLog(@"Error activating audio session: %@", error.localizedDescription);
    }
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    backgroundImageView.image = self.albumArt ?: [UIImage imageNamed:@"PlaceholderCover"];
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    backgroundImageView.clipsToBounds = YES;
    backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:backgroundImageView];
    
    UIToolbar *blurToolbar = [[UIToolbar alloc] initWithFrame:backgroundImageView.bounds];
    blurToolbar.barStyle = UIBarStyleBlack;
    blurToolbar.translucent = YES;
    blurToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [backgroundImageView addSubview:blurToolbar];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    self.albumArtImageView = [[UIImageView alloc] initWithImage:self.albumArt ?: [UIImage imageNamed:@"PlaceholderCover"]];
    self.albumArtImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.albumArtImageView];
    
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = self.songTitle ?: @"Unknown Song";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.titleLabel];
    
    self.albumLabel = [[UILabel alloc] init];
    self.albumLabel.text = self.albumName ?: @"Unknown Album";
    self.albumLabel.textAlignment = NSTextAlignmentCenter;
    self.albumLabel.font = [UIFont systemFontOfSize:18];
    self.albumLabel.textColor = [UIColor whiteColor];
    self.albumLabel.backgroundColor = [UIColor clearColor];
    self.albumLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.albumLabel];
    
    self.artistLabel = [[UILabel alloc] init];
    self.artistLabel.text = self.artistName ?: @"Unknown Artist";
    self.artistLabel.textAlignment = NSTextAlignmentCenter;
    self.artistLabel.font = [UIFont systemFontOfSize:16];
    self.artistLabel.textColor = [UIColor whiteColor];
    self.artistLabel.backgroundColor = [UIColor clearColor];
    self.artistLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.artistLabel];
    
    self.seekSlider = [[UISlider alloc] init];
    self.seekSlider.minimumValue = 0;
    [self.seekSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.seekSlider addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [self.scrollView addSubview:self.seekSlider];
    
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.textColor = [UIColor whiteColor];
    self.currentTimeLabel.font = [UIFont systemFontOfSize:12];
    self.currentTimeLabel.text = @"0:00";
    self.currentTimeLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.currentTimeLabel];
    
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    self.durationLabel.text = @"--:--";
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.durationLabel];
    
    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    
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
    
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf updateProgress:time];
    }];
    
    [self.audioPlayer addObserver:self forKeyPath:@"currentItem.status" options:NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    
    [self togglePlayPause];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.isViewVisible) return;
        
        if ([keyPath isEqualToString:@"currentItem.status"]) {
            if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                [self updateNowPlayingInfo];
            }
        } else if ([keyPath isEqualToString:@"rate"]) {
            [self updateNowPlayingInfo];
            [self updatePlayPauseButtonState];
        }
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat padding = 20.0;
    CGFloat currentY = 20.0;
    
    CGFloat toolbarHeight = 50.0;
    CGFloat toolbarY = self.view.frame.size.height - self.tabBarController.tabBar.frame.size.height;
    if (self.navigationController) {
        toolbarY = self.view.bounds.size.height - toolbarHeight;
    }
    
    if (self.tabBarController && !self.tabBarController.tabBar.hidden) {
        toolbarY -= self.tabBarController.tabBar.frame.size.height;
    }
    
    toolbarY = self.view.bounds.size.height - toolbarHeight;
    self.toolbar.frame = CGRectMake(0, toolbarY, width, toolbarHeight);
    
    self.scrollView.frame = CGRectMake(0, 0, width, toolbarY);
    
    CGFloat maxImageHeight = self.view.bounds.size.height * 0.4;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        maxImageHeight = self.view.bounds.size.height * 0.5;
    }
    
    CGFloat imageWidth = width - 2 * padding;
    CGFloat imageHeight = MIN(imageWidth, maxImageHeight);
    
    self.albumArtImageView.frame = CGRectMake(padding, currentY, imageWidth, imageHeight);
    currentY += imageHeight + 20;
    
    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, titleSize.height);
    currentY += titleSize.height + 10;
    
    CGSize albumSize = [self.albumLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.albumLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, albumSize.height);
    currentY += albumSize.height + 10;
    
    CGSize artistSize = [self.artistLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.artistLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, artistSize.height);
    currentY += artistSize.height + 20;
    
    self.seekSlider.frame = CGRectMake(padding, currentY, width - 2 * padding, 30);
    currentY += 30 + 5;
    
    self.currentTimeLabel.frame = CGRectMake(padding, currentY, 100, 20);
    self.durationLabel.frame = CGRectMake(width - padding - 100, currentY, 100, 20);
    currentY += 20 + 20;
    
    self.scrollView.contentSize = CGSizeMake(width, currentY);
}

- (void)sliderValueChanged:(UISlider *)slider {
    self.currentTimeLabel.text = [self formatTime:slider.value];
}

- (void)sliderTouchDown:(UISlider *)slider {
    self.isSeeking = YES;
}

- (void)sliderTouchUp:(UISlider *)slider {
    CMTime time = CMTimeMakeWithSeconds(slider.value, 1000);
    [self.audioPlayer seekToTime:time completionHandler:^(BOOL finished) {
        self.isSeeking = NO;
        [self updateNowPlayingInfo];
    }];
}

- (void)updateProgress:(CMTime)time {
    if (self.isSeeking) return;
    
    NSTimeInterval currentTime = CMTimeGetSeconds(time);
    NSTimeInterval duration = CMTimeGetSeconds(self.audioPlayer.currentItem.duration);
    
    if (isnan(duration) || duration <= 0) {
        self.seekSlider.value = 0;
        self.seekSlider.maximumValue = 1;
        self.currentTimeLabel.text = @"0:00";
        self.durationLabel.text = @"--:--";
        return;
    }
    
    self.seekSlider.maximumValue = duration;
    self.seekSlider.value = currentTime;
    
    self.currentTimeLabel.text = [self formatTime:currentTime];
    self.durationLabel.text = [self formatTime:duration];
    
    if (currentTime < 2.0 && self.audioPlayer.rate > 0 && self.isViewVisible) {
        [self updateNowPlayingInfo];
    }
}

- (NSString *)formatTime:(NSTimeInterval)totalSeconds {
    int seconds = (int)totalSeconds % 60;
    int minutes = ((int)totalSeconds / 60) % 60;
    int hours = (int)totalSeconds / 3600;
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    }
}

- (void)togglePlayPause {
    NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
    UIBarButtonItem *playPauseItem = toolbarItems[3];
    
    if (self.audioPlayer.rate > 0.0) {
        [self.audioPlayer pause];
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayPause)];
    } else {
        [self.audioPlayer play];
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(togglePlayPause)];
    }
    [self updateNowPlayingInfo];
    playPauseItem.tintColor = [UIColor whiteColor];
    [toolbarItems replaceObjectAtIndex:3 withObject:playPauseItem];
    [self.toolbar setItems:toolbarItems animated:NO];
}

- (void)updatePlayPauseButtonState {
    NSMutableArray *toolbarItems = [self.toolbar.items mutableCopy];
    UIBarButtonItem *playPauseItem = toolbarItems[3];
    
    if (self.audioPlayer.rate > 0.0) {
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(togglePlayPause)];
    } else {
        playPauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayPause)];
    }
    playPauseItem.tintColor = [UIColor whiteColor];
    [toolbarItems replaceObjectAtIndex:3 withObject:playPauseItem];
    [self.toolbar setItems:toolbarItems animated:NO];
}

- (void)skipToNextSong {
    if (self.currentIndex + 1 < self.songList.count) {
        self.currentIndex++;
        [self updatePlayerWithCurrentSong];
    } else if (self.isLooping) {
        self.currentIndex = 0;
        [self updatePlayerWithCurrentSong];
    }
}

- (void)skipToPreviousSong {
    NSTimeInterval currentTime = CMTimeGetSeconds(self.audioPlayer.currentTime);
    if (currentTime > 3.0) {
        [self.audioPlayer seekToTime:kCMTimeZero];
        [self updateNowPlayingInfo];
    } else {
        if (self.currentIndex > 0) {
            self.currentIndex--;
            [self updatePlayerWithCurrentSong];
        } else if (self.isLooping) {
            self.currentIndex = self.songList.count - 1;
            [self updatePlayerWithCurrentSong];
        }
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
    } else if (self.isLooping) {
        self.currentIndex = 0;
        [self updatePlayerWithCurrentSong];
    }
}

- (void)updateNowPlayingInfo {
    NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
    if (self.songTitle) nowPlayingInfo[MPMediaItemPropertyTitle] = self.songTitle;
    if (self.artistName) nowPlayingInfo[MPMediaItemPropertyArtist] = self.artistName;
    if (self.albumName) nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = self.albumName;
    
    if (self.albumArtImageView.image) {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:self.albumArtImageView.image];
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork;
    }
    
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @(self.audioPlayer.rate);
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(CMTimeGetSeconds(self.audioPlayer.currentTime));
    
    NSTimeInterval duration = CMTimeGetSeconds(self.audioPlayer.currentItem.duration);
    if (!isnan(duration) && duration > 0) {
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = @(duration);
    }
    
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
    self.artistName = currentSong[@"AlbumArtist"] ?: currentSong[@"Artist"];
    self.albumName = currentSong[@"Album"];
    self.titleLabel.text = self.songTitle;
    self.artistLabel.text = self.artistName;
    self.albumLabel.text = self.albumName;
    self.songURL = songUrl;
    
    if (self.audioPlayer.currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.audioPlayer.currentItem];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:coverUrl];
        UIImage *coverImage = imageData ? [UIImage imageWithData:imageData] : [UIImage imageNamed:@"PlaceholderCover"];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.albumArtImageView.image = coverImage;
            
            AVPlayerItem *nextItem = [AVPlayerItem playerItemWithURL:songUrl];
            [self.audioPlayer replaceCurrentItemWithPlayerItem:nextItem];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(songDidFinish:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:nextItem];
            
            [self.audioPlayer play];
            [self updatePlayPauseButtonState];
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
    self.isViewVisible = YES;
    [self.view addSubview:self.toolbar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.isViewVisible = NO;
    if (self.audioPlayer) {
        [self.audioPlayer pause];
        [self updatePlayPauseButtonState];
    }
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
}
- (void)dealloc {
    if (self.timeObserver) {
        [self.audioPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    @try {
        [self.audioPlayer removeObserver:self forKeyPath:@"currentItem.status"];
        [self.audioPlayer removeObserver:self forKeyPath:@"rate"];
    } @catch (NSException *exception) {}
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
