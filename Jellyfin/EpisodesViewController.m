//
//  EpisodesViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "EpisodesViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "SVProgressHUD/SVProgressHUD.h"
#include <sys/sysctl.h>
#import "Artwork.h"
#import "AppDelegate.h"

@interface EpisodesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *episodes;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation EpisodesViewController

- (NSString *)deviceModelIdentifier {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *identifier = [NSString stringWithUTF8String:machine];
    free(machine);
    return identifier;
}

- (NSString *)deviceName {
    NSString *modelIdentifier = [self deviceModelIdentifier];
    NSDictionary *modelMapping = @{
                                   //scary
                                   @"x86_64": @"Xcode Simulator",
                                   //iphone
                                   @"iPhone2,1": @"iPhone 3GS",
                                   @"iPhone3,1": @"iPhone 4",
                                   @"iPhone3,2": @"iPhone 4",
                                   @"iPhone3,3": @"iPhone 4",
                                   @"iPhone4,1": @"iPhone 4S",
                                   @"iPhone5,1": @"iPhone 5",
                                   @"iPhone5,2": @"iPhone 5",
                                   @"iPhone5,3": @"iPhone 5c",
                                   @"iPhone5,4": @"iPhone 5c",
                                   @"iPhone6,1": @"iPhone 5s",
                                   @"iPhone6,2": @"iPhone 5s",
                                   @"iPhone7,1": @"iPhone 6 Plus",
                                   @"iPhone7,2": @"iPhone 6",
                                   // no iphone 6s and later, screw you
                                   //ipad
                                   @"iPad2,1": @"iPad 2",
                                   @"iPad2,2": @"iPad 2",
                                   @"iPad2,3": @"iPad 2",
                                   @"iPad2,4": @"iPad 2",
                                   @"iPad3,1": @"iPad 3",
                                   @"iPad3,2": @"iPad 3",
                                   @"iPad3,3": @"iPad 3",
                                   @"iPad3,4": @"iPad 4",
                                   @"iPad3,5": @"iPad 4",
                                   @"iPad3,6": @"iPad 4",
                                   @"iPad2,5": @"iPad mini",
                                   @"iPad2,6": @"iPad mini",
                                   @"iPad2,7": @"iPad mini",
                                   @"iPad4,1": @"iPad Air",
                                   @"iPad4,2": @"iPad Air",
                                   @"iPad4,4": @"iPad mini 2",
                                   @"iPad4,5": @"iPad mini 2",
                                   @"iPad5,3": @"iPad Air 2",
                                   @"iPad5,4": @"iPad Air 2",
                                   @"iPad4,7": @"iPad mini 3",
                                   @"iPad4,8": @"iPad mini 3",
                                   // no later, screw you
                                   //ipod touch
                                   @"iPod4,1": @"iPod touch (4th generation)",
                                   @"iPod5,1": @"iPod touch (5th generation)",
                                   @"iPod7,1": @"iPod touch (6th generation)",
                                   //s
                                   };
    
    NSString *friendlyName = modelMapping[modelIdentifier];
    NSLog(@"%@", modelIdentifier);
    return friendlyName ?: modelIdentifier;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    [SVProgressHUD showWithStatus:@"Loading episodes..."];
    self.title = self.viewTitle;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshEpisodes) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Shows/%@/Episodes", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], self.showId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [self fetchEpisodes];
}

- (void)fetchEpisodes {
    NSString *urlString = [NSString stringWithFormat:@"%@/Shows/%@/Episodes", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], self.showId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection) {
        [SVProgressHUD showWithStatus:@"Loading episodes..."];
    } else {
        NSLog(@"Error: Failed to create the connection");
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.receivedData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:self.receivedData options:0 error:nil];
    self.episodes = json[@"Items"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [SVProgressHUD dismiss];
        [self.refreshControl endRefreshing];
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Error fetching episodes: %@", error);
    [SVProgressHUD dismiss];
    [self.refreshControl endRefreshing];
}

- (void)refreshEpisodes {
    [SVProgressHUD showWithStatus:@"Refreshing episodes..."];
    
    [self fetchEpisodes];
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.episodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(tableView) weakTableView = tableView;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EpisodeCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"EpisodeCell"];
    }
    
    NSDictionary *episode = self.episodes[indexPath.row];
    cell.textLabel.text = episode[@"Name"];
    
    NSString *season = [NSString stringWithFormat:@"Season %@", episode[@"ParentIndexNumber"]];
    NSString *epid = [NSString stringWithFormat:@"Episode %@", episode[@"IndexNumber"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", season, epid];
    NSString *episodeId = episode[@"Id"];
    ArtworkCache *cachedArtwork = [Artwork fetchArtworkForId:episodeId inContext:self.managedObjectContext];
    if (cachedArtwork) {
        UIImage *image = [UIImage imageWithData:cachedArtwork.imageData];
        if (image) {
            [self.imageCache setObject:image forKey:episodeId];
            cell.imageView.image = image;
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary?quality=50&height=360&width=640", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], episodeId];
            NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    [self.imageCache setObject:image forKey:episodeId];
                    
                    [Artwork saveArtworkInBackground:imageData forId:episodeId mainContext:self.managedObjectContext completion:nil];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UITableViewCell *updateCell = [weakTableView cellForRowAtIndexPath:indexPath];
                        if (updateCell) {
                            updateCell.imageView.image = image;
                            [updateCell setNeedsLayout];
                        }
                    });
                }
            }
        });
    }
    return cell;
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *episode = self.episodes[indexPath.row];
    NSString *videoId = episode[@"Id"];
    
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
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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


@end
