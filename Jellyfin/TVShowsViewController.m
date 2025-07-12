//
//  TVShowsViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "TVShowsViewController.h"
#import "EpisodesViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#include <sys/sysctl.h>
#import "Artwork.h"
#import "AppDelegate.h"

@interface TVShowsViewController ()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation TVShowsViewController

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
    [self.audioPlayer seekToTime:CMTimeMake(0, 1)];
    [self.audioPlayer pause];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshShows) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    
    [SVProgressHUD showWithStatus:@"Loading shows..."];
    
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    [self fetchShows];
}

- (void)fetchShows {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    
    if (!serverUrl || !token) {
        NSLog(@"Server URL or token is missing.");
        [SVProgressHUD dismiss];
        [self.refreshControl endRefreshing];
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Items?IncludeItemTypes=Series&ParentId=a656b907eb3a73532e40e44b968d0225&SortBy=Name&SortOrder=Ascending", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                   [SVProgressHUD dismiss];
                                   [self.refreshControl endRefreshing];
                                   return;
                               }
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   if (jsonError) {
                                       NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
                                       [SVProgressHUD dismiss];
                                       [self.refreshControl endRefreshing];
                                       return;
                                   }
                                   self.shows = jsonResponse[@"Items"];
                                   if ([self.shows isKindOfClass:[NSArray class]]) {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [self.tableView reloadData];
                                           [self.refreshControl endRefreshing];
                                           [SVProgressHUD dismiss];
                                       });
                                   }
                               }
                           }];
}

- (void)refreshShows {
    [SVProgressHUD showWithStatus:@"Refreshing shows..."];
    
    [self fetchShows];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.shows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(tableView) weakTableView = tableView;
    static NSString *cellIdentifier = @"ShowCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *show = self.shows[indexPath.row];
    cell.textLabel.text = show[@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Rated %@ • %@", show[@"OfficialRating"], show[@"ProductionYear"]];
    cell.imageView.image = [UIImage imageNamed:@"PlaceholderPoster"];
    
    NSString *showId = show[@"Id"];
    ArtworkCache *cachedArtwork = [Artwork fetchArtworkForId:showId inContext:self.managedObjectContext];
    if (cachedArtwork) {
        UIImage *image = [UIImage imageWithData:cachedArtwork.imageData];
        if (image) {
            [self.imageCache setObject:image forKey:showId];
            cell.imageView.image = image;
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary?quality=50&height=660&width=440", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], showId];
            NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    [self.imageCache setObject:image forKey:showId];
                    
                    [Artwork saveArtworkInBackground:imageData forId:showId mainContext:self.managedObjectContext completion:nil];
                    
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

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *selectedShow = self.shows[indexPath.row];
    NSString *showId = selectedShow[@"Id"];
    NSString *showTitle = selectedShow[@"Name"];
    
    EpisodesViewController *episodesVC = [[EpisodesViewController alloc] init];
    episodesVC.showId = showId;
    episodesVC.viewTitle = showTitle;
    [self.navigationController pushViewController:episodesVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
