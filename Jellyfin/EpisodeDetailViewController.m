//
//  EpisodeDetailViewController.m
//  Jellyfin
//
//  Created by bruhdude on 3/9/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "EpisodeDetailViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "SVProgressHUD/SVProgressHUD.h"
#import "Artwork.h"
#import "AppDelegate.h"

@interface EpisodeDetailViewController ()

@property (nonatomic, strong) UIImageView *backdropImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *overviewLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation EpisodeDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.viewTitle;
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    self.backdropImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width * 9.0 / 16.0)];
    self.backdropImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backdropImageView.clipsToBounds = YES;
    self.backdropImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:self.backdropImageView];
    
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.frame = CGRectMake((self.view.bounds.size.width - 60) / 2, (self.backdropImageView.frame.size.height - 60) / 2, 60, 60);
    self.playButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.playButton.layer.cornerRadius = 30;
    self.playButton.clipsToBounds = YES;
    self.playButton.imageEdgeInsets = UIEdgeInsetsMake(15, 15, 15, 15);
    [self.playButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(playEpisode) forControlEvents:UIControlEventTouchUpInside];
    self.playButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:self.playButton];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, CGRectGetMaxY(self.backdropImageView.frame) + 15, self.view.bounds.size.width - 30, 0)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.titleLabel.numberOfLines = 0;
    
    NSString *seasonNum = self.episode[@"ParentIndexNumber"] ? [NSString stringWithFormat:@"%@", self.episode[@"ParentIndexNumber"]] : @"";
    NSString *episodeNum = self.episode[@"IndexNumber"] ? [NSString stringWithFormat:@"%@", self.episode[@"IndexNumber"]] : @"";
    NSString *titleStr = self.episode[@"Name"] ?: @"Unknown Title";
    
    if (seasonNum.length > 0 && episodeNum.length > 0) {
        self.titleLabel.text = [NSString stringWithFormat:@"Season %@ - %@. %@", seasonNum, episodeNum, titleStr];
    } else {
        self.titleLabel.text = titleStr;
    }
    
    [self.titleLabel sizeToFit];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:self.titleLabel];
    
    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, CGRectGetMaxY(self.titleLabel.frame) + 5, self.view.bounds.size.width - 30, 0)];
    self.infoLabel.font = [UIFont systemFontOfSize:14];
    self.infoLabel.textColor = [UIColor darkGrayColor];
    self.infoLabel.numberOfLines = 1;
    
    NSString *infoText = @"";
    NSNumber *runTimeTicks = self.episode[@"RunTimeTicks"];
    if (runTimeTicks && ![runTimeTicks isKindOfClass:[NSNull class]]) {
        long long ticks = [runTimeTicks longLongValue];
        long long totalSeconds = ticks / 10000000;
        long long hours = totalSeconds / 3600;
        long long minutes = (totalSeconds % 3600) / 60;
        
        if (hours > 0) {
            infoText = [infoText stringByAppendingFormat:@"%lldh %lldm", hours, minutes];
        } else {
            infoText = [infoText stringByAppendingFormat:@"%lldm", minutes];
        }
    }
    
    NSString *premiereDateString = self.episode[@"PremiereDate"];
    if (premiereDateString && ![premiereDateString isKindOfClass:[NSNull class]]) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSS'Z'"];
        NSDate *date = [dateFormatter dateFromString:premiereDateString];
        
        if (!date) {
            [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
            date = [dateFormatter dateFromString:premiereDateString];
        }
        
        if (date) {
            NSDateFormatter *displayFormatter = [[NSDateFormatter alloc] init];
            [displayFormatter setDateFormat:@"MM/dd/yyyy"];
            NSString *displayDate = [displayFormatter stringFromDate:date];
            
            if (infoText.length > 0) {
                infoText = [infoText stringByAppendingFormat:@" • %@", displayDate];
            } else {
                infoText = displayDate;
            }
        }
    }
    
    self.infoLabel.text = infoText;
    [self.infoLabel sizeToFit];
    self.infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:self.infoLabel];
    
    self.overviewLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, CGRectGetMaxY(self.infoLabel.frame) + 10, self.view.bounds.size.width - 30, 0)];
    self.overviewLabel.font = [UIFont systemFontOfSize:14];
    self.overviewLabel.numberOfLines = 0;
    self.overviewLabel.text = self.episode[@"Overview"] ?: @"No description available.";
    [self.overviewLabel sizeToFit];
    self.overviewLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.scrollView addSubview:self.overviewLabel];
    
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, CGRectGetMaxY(self.overviewLabel.frame) + 20);
    
    [self loadBackdropImage];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.backdropImageView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width * 9.0 / 16.0);
    self.playButton.frame = CGRectMake((self.view.bounds.size.width - 60) / 2, (self.backdropImageView.frame.size.height - 60) / 2, 60, 60);
    
    self.titleLabel.frame = CGRectMake(15, CGRectGetMaxY(self.backdropImageView.frame) + 15, self.view.bounds.size.width - 30, 0);
    [self.titleLabel sizeToFit];
    
    self.infoLabel.frame = CGRectMake(15, CGRectGetMaxY(self.titleLabel.frame) + 5, self.view.bounds.size.width - 30, 0);
    [self.infoLabel sizeToFit];
    
    self.overviewLabel.frame = CGRectMake(15, CGRectGetMaxY(self.infoLabel.frame) + 10, self.view.bounds.size.width - 30, 0);
    [self.overviewLabel sizeToFit];
    
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, CGRectGetMaxY(self.overviewLabel.frame) + 20);
}

- (void)loadBackdropImage {
    NSString *episodeId = self.episode[@"Id"];
    NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary?quality=90&maxWidth=1280", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], episodeId];
    NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.backdropImageView.image = image;
                });
            }
        }
    });
}

- (void)playEpisode {
    NSString *videoId = self.episode[@"Id"];
    
    NSString *videoUrlString = [NSString stringWithFormat:@"%@/Videos/%@/stream.mp4?static=true&container=mp4", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], videoId];
    NSURL *videoUrl = [NSURL URLWithString:videoUrlString];
    
    if (!videoUrl) {
        NSLog(@"Error: Invalid video URL for video ID: %@", videoId);
        [self showError:@"Invalid video URL"];
        return;
    }
    
    MPMoviePlayerViewController *moviePlayerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:videoUrl];
    
    if (!moviePlayerVC) {
        NSLog(@"Error: Failed to create movie player view controller");
        [self showError:@"Failed to load the video player"];
        return;
    }
    
    [self presentMoviePlayerViewControllerAnimated:moviePlayerVC];
    [moviePlayerVC.moviePlayer play];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:moviePlayerVC.moviePlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerPlaybackError:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:moviePlayerVC.moviePlayer];
}

- (void)moviePlayerDidFinish:(NSNotification *)notification {
    NSLog(@"Movie playback finished");
}

- (void)moviePlayerPlaybackError:(NSNotification *)notification {
    MPMoviePlayerController *moviePlayer = notification.object;
    
    if (moviePlayer.loadState == MPMovieLoadStateStalled) {
        NSLog(@"Error: Video playback stalled for video URL: %@", moviePlayer.contentURL);
        [self showError:@"An error occurred during video playback"];
    }
}

- (void)showError:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

@end
