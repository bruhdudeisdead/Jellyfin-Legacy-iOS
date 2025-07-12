//
//  MoviesViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "MoviesViewController.h"
#import "MovieViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#include <sys/sysctl.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "Artwork.h"
#import "AppDelegate.h"

@interface MoviesViewController ()

@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) NSDictionary *selectedMovie2;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation MoviesViewController

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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    [SVProgressHUD showWithStatus:@"Loading movies..."];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshMovies) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    [self fetchMovies];
}

- (void)refreshMovies {
    [SVProgressHUD showWithStatus:@"Refreshing movies..."];
    
    [self fetchMovies];
}

- (void)fetchMovies {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    if(!serverUrl || !token) {
        NSLog(@"server url or token is missing.");
        [SVProgressHUD dismiss];
        return;
    }
    NSString *urlString = [NSString stringWithFormat:@"%@/Items?IncludeItemTypes=Movie&ParentId=f137a2dd21bbc1b99aa5c0f6bf02a805&SortBy=Name&SortOrder=Ascending", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if(connectionError) {
                                   NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                   [SVProgressHUD dismiss];
                                   [self.refreshControl endRefreshing];
                                   return;
                               }
                               if(data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if(jsonError) {
                                       NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
                                       [SVProgressHUD dismiss];
                                       [self.refreshControl endRefreshing];
                                       return;
                                   }
                                   self.movies = jsonResponse[@"Items"];
                                   if([self.movies isKindOfClass:[NSArray class]]) {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [self.tableView reloadData];
                                           [self.refreshControl endRefreshing];
                                           [SVProgressHUD dismiss];
                                       });
                                   }
                               }
                           }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.movies.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(tableView) weakTableView = tableView;
    static NSString *cellIdentifier = @"MovieCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *movie = self.movies[indexPath.row];
    cell.textLabel.text = movie[@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Rated %@ • %@", movie[@"OfficialRating"], movie[@"ProductionYear"]];
    cell.imageView.image = [UIImage imageNamed:@"PlaceholderPoster"];
    BOOL loadImagesPoster = [[NSUserDefaults standardUserDefaults] boolForKey:@"image_load_posters"];
    if (loadImagesPoster == YES) {
        NSString *movieId = movie[@"Id"];
        ArtworkCache *cachedArtwork = [Artwork fetchArtworkForId:movieId inContext:self.managedObjectContext];
        if (cachedArtwork) {
            UIImage *image = [UIImage imageWithData:cachedArtwork.imageData];
            if (image) {
                [self.imageCache setObject:image forKey:movieId];
                cell.imageView.image = image;
            }
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary?quality=80&height=660&width=440", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], movieId];
                NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
                NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
                if (imageData) {
                    UIImage *image = [UIImage imageWithData:imageData];
                    if (image) {
                        [self.imageCache setObject:image forKey:movieId];
                        
                        [Artwork saveArtworkInBackground:imageData forId:movieId mainContext:self.managedObjectContext completion:nil];
                        
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

    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *selectedMovie = self.movies[indexPath.row];
    NSString *movieId = selectedMovie[@"Id"];
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    if(!serverUrl || !token) {
        NSLog(@"server url or token is missing.");
        [SVProgressHUD dismiss];
        return;
    }
    NSString *urlString = [NSString stringWithFormat:@"%@/Items/%@", serverUrl, movieId];
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"%@", urlString);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    NSLog(@"%@", authHeader);
    [SVProgressHUD showWithStatus:@"Loading..."];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if(connectionError) {
                                   NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                   [SVProgressHUD dismiss];
                                   return;
                               }
                               if(data) {
                                   NSString *rawString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                   NSLog(@"Raw JSON Response: %@", rawString);

                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if(jsonError) {
                                       NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
                                       [SVProgressHUD dismiss];
                                       return;
                                   }
                                   self.selectedMovie2 = jsonResponse;
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           NSString *posterUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], movieId];
                                           NSURL *posterUrl = [NSURL URLWithString:posterUrlString];
                                           
                                           __block UIImage *posterImage = [UIImage imageNamed:@"placeholder"];
                                           dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                               NSData *imageData = [NSData dataWithContentsOfURL:posterUrl];
                                               if (imageData) {
                                                   posterImage = [UIImage imageWithData:imageData];
                                               }
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   MovieViewController *movieVC = [[MovieViewController alloc] init];
                                                   
                                                   movieVC.movieId = selectedMovie[@"Id"];
                                                   movieVC.moviePoster = posterImage;
                                                   movieVC.movieTitle = self.selectedMovie2[@"Name"];
                                                   movieVC.movieTagline = self.selectedMovie2[@"Taglines"][0];
                                                   movieVC.movieProductionYear = self.selectedMovie2[@"ProductionYear"];
                                                   movieVC.movieOverview = self.selectedMovie2[@"Overview"];
                                                   
                                                   [self.navigationController pushViewController:movieVC animated:YES];
                                                   [SVProgressHUD dismiss];
                                               });
                                           });

                                       });
                               }
                           }];
    
    //fuckass
    //NSDictionary *movie = self.movies[indexPath.row];
    //NSString *videoId = movie[@"Id"];
    
    //NSString *videoUrlString = [NSString stringWithFormat:@"%@/Videos/%@/stream.mp4?static=true&container=mp4", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], videoId];
    //NSURL *videoUrl = [NSURL URLWithString:videoUrlString];
    
    //if (!videoUrl) {
    //    NSLog(@"Error: Invalid video URL for video ID: %@", videoId);
    //    [self showError:@"Invalid video URL"];
    //    return;
    //}
    
    //MPMoviePlayerViewController *moviePlayerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:videoUrl];
    
    //if (!moviePlayerVC) {
    //    NSLog(@"Error: Failed to create movie player view controller");
    //    [self showError:@"Failed to load the video player"];
    //    return;
    //}
    
    //NSLog(@"Presenting movie player with URL: %@", videoUrl);
    //[self presentMoviePlayerViewControllerAnimated:moviePlayerVC];
    
    //[moviePlayerVC.moviePlayer play];
    //NSLog(@"Started playback for video: %@", videoId);
    
    //[[NSNotificationCenter defaultCenter] addObserver:self
    //                                         selector:@selector(moviePlayerDidFinish:)
    //                                             name:MPMoviePlayerPlaybackDidFinishNotification
    //                                           object:moviePlayerVC.moviePlayer];
    
    //[[NSNotificationCenter defaultCenter] addObserver:self
    //                                         selector:@selector(moviePlayerPlaybackError:)
    //                                             name:MPMoviePlayerLoadStateDidChangeNotification
    //                                           object:moviePlayerVC.moviePlayer];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100.0;
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

