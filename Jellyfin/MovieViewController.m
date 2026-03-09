//
//  MovieViewController.m
//  Jellyfin
//
//  Created by Jack on 2/22/25.
//  Copyright (c) 2025 bruhdude. All rights reserved.
//

#import "MovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface MovieViewController ()

@property (nonatomic, strong) UIImageView *moviePosterImageView;
@property (nonatomic, strong) UILabel *movieTitleLabel;
@property (nonatomic, strong) UILabel *movieTaglineLabel;
@property (nonatomic, strong) UILabel *movieOverviewLabel;
@property (nonatomic, strong) UILabel *movieProductionYearLabel;
@property (nonatomic, strong) UIButton *moviePlayButton;
@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation MovieViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.movieTitle;
    self.view.backgroundColor = [UIColor whiteColor];
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    backgroundImageView.image = self.moviePoster;
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
    
    self.moviePosterImageView = [[UIImageView alloc] initWithImage:self.moviePoster];
    self.moviePosterImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.moviePosterImageView];
    
    self.movieTitleLabel = [[UILabel alloc] init];
    self.movieTitleLabel.text = self.movieTitle ?: @"Unknown Movie";
    self.movieTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.movieTitleLabel.textColor = [UIColor whiteColor];
    self.movieTitleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.movieTitleLabel.numberOfLines = 0;
    self.movieTitleLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.movieTitleLabel];
    
    self.movieTaglineLabel = [[UILabel alloc] init];
    self.movieTaglineLabel.text = self.movieTagline ?: @"";
    self.movieTaglineLabel.textAlignment = NSTextAlignmentCenter;
    self.movieTaglineLabel.font = [UIFont italicSystemFontOfSize:18];
    self.movieTaglineLabel.textColor = [UIColor lightGrayColor];
    self.movieTaglineLabel.numberOfLines = 0;
    self.movieTaglineLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.movieTaglineLabel];
    
    self.movieOverviewLabel = [[UILabel alloc] init];
    self.movieOverviewLabel.text = self.movieOverview ?: @"No overview available.";
    self.movieOverviewLabel.textAlignment = NSTextAlignmentLeft;
    self.movieOverviewLabel.font = [UIFont systemFontOfSize:16];
    self.movieOverviewLabel.textColor = [UIColor whiteColor];
    self.movieOverviewLabel.numberOfLines = 0;
    self.movieOverviewLabel.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:self.movieOverviewLabel];
    
    BOOL isiOS7OrLater = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
    
    if (isiOS7OrLater) {
        self.moviePlayButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.moviePlayButton setTitle:@"Play" forState:UIControlStateNormal];
        self.moviePlayButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        self.moviePlayButton.layer.cornerRadius = 5;
        self.moviePlayButton.clipsToBounds = YES;
        self.moviePlayButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8];
        [self.moviePlayButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        self.moviePlayButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [self.moviePlayButton setTitle:@"Play" forState:UIControlStateNormal];
        self.moviePlayButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    }
    
    [self.scrollView addSubview:self.moviePlayButton];
    
    [self.moviePlayButton addTarget:self action:@selector(playMovie) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat padding = 20.0;
    CGFloat currentY = 20.0;
    
    CGFloat posterHeight = 300;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        posterHeight = 450;
    }
    self.moviePosterImageView.frame = CGRectMake(padding, currentY, width - 2 * padding, posterHeight);
    currentY += posterHeight + 20;
    
    CGSize titleSize = [self.movieTitleLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.movieTitleLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, titleSize.height);
    currentY += titleSize.height + 10;
    
    if (self.movieTaglineLabel.text.length > 0) {
        CGSize taglineSize = [self.movieTaglineLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
        self.movieTaglineLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, taglineSize.height);
        currentY += taglineSize.height + 15;
    } else {
        self.movieTaglineLabel.frame = CGRectZero;
    }
    
    self.moviePlayButton.frame = CGRectMake(padding, currentY, width - 2 * padding, 50);
    currentY += 50 + 20;
    
    CGSize overviewSize = [self.movieOverviewLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.movieOverviewLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, overviewSize.height);
    currentY += overviewSize.height + 100;
    
    CGFloat minContentHeight = self.view.bounds.size.height + 1;
    if (currentY < minContentHeight) {
        currentY = minContentHeight;
    }
    
    self.scrollView.contentSize = CGSizeMake(width, currentY);
}

- (void)playMovie {
    NSString *videoId = self.movieId;
    
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
    
    NSLog(@"Presenting movie player with URL: %@", videoUrl);
    [self presentMoviePlayerViewControllerAnimated:moviePlayerVC];
    
    [moviePlayerVC.moviePlayer play];
    NSLog(@"Started playback for video: %@", videoId);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:moviePlayerVC.moviePlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerPlaybackError:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:moviePlayerVC.moviePlayer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)moviePlayerDidFinish:(NSNotification *)notification {
    NSLog(@"Movie playback finished");
}


- (void)moviePlayerPlaybackError:(NSNotification *)notification {
    MPMoviePlayerController *moviePlayer = notification.object;
    
    NSLog(@"Movie player load state changed: %ld", (long)moviePlayer.loadState);
    
    if (moviePlayer.loadState == MPMovieLoadStateStalled) {
        NSLog(@"Error: Video playback stalled for video URL: %@", moviePlayer.contentURL);
        [self showError:@"An error occurred during video playback"];
    }
}

- (void)showError:(NSString *)message {
    NSLog(@"Showing error message: %@", message);
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
