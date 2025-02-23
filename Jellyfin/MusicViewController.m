//
//  MusicViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "MusicViewController.h"
#import "AlbumViewController.h"
#import "NowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "SVProgressHUD/SVProgressHUD.h"
#include <sys/sysctl.h>

@interface MusicViewController ()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) NSMutableDictionary *imageCache;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@end

@implementation MusicViewController

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
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshMusic) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    [SVProgressHUD showWithStatus:@"Loading music..."];
    [self fetchMusic];
}

- (void)fetchMusic {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    if(!serverUrl || !token) {
        NSLog(@"server url or token is missing.");
        [self.refreshControl endRefreshing];
        [SVProgressHUD dismiss];
        return;
    }
    NSString *urlString = [NSString stringWithFormat:@"%@/Items?IncludeItemTypes=MusicAlbum&Recursive=true&Fields=PrimaryImageAspectRatio,SortName&ParentId=7e64e319657a9516ec78490da03edccb&SortOrder=Ascending&SortBy=SortName", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
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
                                   self.music = jsonResponse[@"Items"];
                                   if([self.music isKindOfClass:[NSArray class]]) {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [SVProgressHUD dismiss];
                                           [self.refreshControl endRefreshing];
                                           [self.tableView reloadData];
                                       });
                                   }
                               }
                           }];
}

- (void)refreshMusic {
    [SVProgressHUD showWithStatus:@"Refreshing music..."];
    
    [self fetchMusic];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.music.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"AlbumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *song = self.music[indexPath.row];
    cell.textLabel.text = song[@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", song[@"AlbumArtist"], song[@"ProductionYear"]];
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    NSString *songId = song[@"Id"];
    
    UIImage *cachedImage = self.imageCache[songId];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        BOOL loadImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"image_load_artwork"];
        if (loadImages == YES) {
        NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], songId];
        NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    self.imageCache[songId] = image;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UITableViewCell *updateCell = [tableView cellForRowAtIndexPath:indexPath];
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
    NSDictionary *selectedAlbum = self.music[indexPath.row];
    NSString *albumId = selectedAlbum[@"Id"];
    NSString *albumTitle = selectedAlbum[@"Name"];
    
    AlbumViewController *fifthVC = [[AlbumViewController alloc] init];
    fifthVC.albumId = albumId;
    fifthVC.albumTitle = albumTitle;
    [self.navigationController pushViewController:fifthVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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



#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

@end
