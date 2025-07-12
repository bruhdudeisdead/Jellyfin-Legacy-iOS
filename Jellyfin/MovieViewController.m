//
//  MovieViewController.m
//  Jellyfin
//
//  Created by Jack on 2/22/25.
//  Copyright (c) 2025 DumbStupidStuff. All rights reserved.
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
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    backgroundImageView.image = self.moviePoster;
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    backgroundImageView.clipsToBounds = YES;
    [self.view addSubview:backgroundImageView];
    
    UIToolbar *blurToolbar = [[UIToolbar alloc] initWithFrame:backgroundImageView.bounds];
    blurToolbar.barStyle = UIBarStyleBlack;
    blurToolbar.translucent = YES;
    [backgroundImageView addSubview:blurToolbar];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height + 250); // Adjust content size to fit everything
    [self.view addSubview:self.scrollView];
    
    self.moviePosterImageView = [[UIImageView alloc] initWithImage:self.moviePoster];
    self.moviePosterImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.moviePosterImageView.frame = CGRectMake(20, 20, self.view.frame.size.width - 40, self.view.frame.size.width - 40);
    [self.scrollView addSubview:self.moviePosterImageView];
    
    self.movieTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.moviePosterImageView.frame) + 10, self.view.frame.size.width - 40, 50)];
    self.movieTitleLabel.text = self.movieTitle ?: @"Unknown Movie";
    self.movieTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.movieTitleLabel.textColor = [UIColor whiteColor];
    self.movieTitleLabel.font = [UIFont systemFontOfSize:20];
    self.movieTitleLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.movieTitleLabel];
    
    self.movieTaglineLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.movieTitleLabel.frame) + 5, self.view.frame.size.width - 40, 20)];
    self.movieTaglineLabel.text = self.movieTagline ?: @"???";
    self.movieTaglineLabel.textAlignment = NSTextAlignmentCenter;
    self.movieTaglineLabel.font = [UIFont boldSystemFontOfSize:18];
    self.movieTaglineLabel.textColor = [UIColor whiteColor];
    self.movieTaglineLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.movieTaglineLabel];
    
    self.movieOverviewLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.movieTaglineLabel.frame) + 5, self.view.frame.size.width - 40, 500)];
    self.movieOverviewLabel.text = self.movieOverview ?: @"Unknown movie. Wow!";
    self.movieOverviewLabel.textAlignment = NSTextAlignmentCenter;
    self.movieOverviewLabel.font = [UIFont systemFontOfSize:16];
    self.movieOverviewLabel.textColor = [UIColor whiteColor];
    self.movieOverviewLabel.numberOfLines = 0;
    [self.scrollView addSubview:self.movieOverviewLabel];
    
    self.moviePlayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.moviePlayButton setTitle:@"Play" forState:UIControlStateNormal];
    self.moviePlayButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.moviePlayButton.layer.cornerRadius = 5;
    self.moviePlayButton.clipsToBounds = YES;
    [self.scrollView addSubview:self.moviePlayButton];
    
    CGSize taglineSize = [self.movieTaglineLabel sizeThatFits:CGSizeMake(self.view.frame.size.width - 40, CGFLOAT_MAX)];
    self.movieTaglineLabel.frame = CGRectMake(20, CGRectGetMaxY(self.movieTitleLabel.frame) + 5, self.view.frame.size.width - 40, taglineSize.height);
    
    CGSize overviewSize = [self.movieOverviewLabel sizeThatFits:CGSizeMake(self.view.frame.size.width - 40, CGFLOAT_MAX)];
    self.movieOverviewLabel.frame = CGRectMake(20, CGRectGetMaxY(self.movieTaglineLabel.frame) + 5, self.view.frame.size.width - 40, overviewSize.height);
    
    self.moviePlayButton.frame = CGRectMake(20, CGRectGetMaxY(self.movieOverviewLabel.frame) + 10, self.view.frame.size.width - 40, 44);
    
    [self.moviePlayButton addTarget:self action:@selector(playMovie) forControlEvents:UIControlEventTouchUpInside];

    [self.scrollView addSubview:self.movieOverviewLabel];
    //ios <7 is EVIL!
    self.movieTitleLabel.backgroundColor = [UIColor clearColor];
    self.movieTaglineLabel.backgroundColor = [UIColor clearColor];
    self.movieOverviewLabel.backgroundColor = [UIColor clearColor];
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
    // Dispose of any resources that can be recreated.
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
