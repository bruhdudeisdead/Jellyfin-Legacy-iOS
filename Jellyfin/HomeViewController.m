//
//  HomeViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "HomeViewController.h"
#import "AlbumViewController.h"
#import "EpisodesViewController.h"
#include <sys/sysctl.h>

@interface HomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITableView *showsTableView;
@property (nonatomic, strong) UITableView *albumsTableView;
@property (nonatomic, strong) NSArray *shows;
@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) NSMutableDictionary *imageCache;

@end

@implementation HomeViewController

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
    NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
    
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] objectForKey:@"server_url"];
    
    if (!token || [token  isEqual: @""] || token == nil) {
        [self displayAlertView:@"Configuration Error" message:@"API key not set. Please set an API key in Settings."];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        return;
    }
    if (!serverUrl || [serverUrl  isEqual: @""] || serverUrl == nil) {
        [self displayAlertView:@"Configuration Error" message:@"Server URL not set. Please set a server URL in Settings."];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        return;
    }
    [self fetchServerData];
    self.imageCache = [NSMutableDictionary dictionary];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    NSLog(@"%lu", (unsigned long)UIViewAutoresizingFlexibleHeight);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    UILabel *showsHeader = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, self.view.bounds.size.width - 30, 30)];
    showsHeader.text = @"Recently Added TV Shows";
    showsHeader.font = [UIFont boldSystemFontOfSize:18];
    [self.scrollView addSubview:showsHeader];
    
    self.showsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 50, self.view.bounds.size.width, 260) style:UITableViewStylePlain];
    self.showsTableView.delegate = self;
    self.showsTableView.dataSource = self;
    self.showsTableView.tag = 1;
    self.showsTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.showsTableView];
    
    UILabel *albumsHeader = [[UILabel alloc] initWithFrame:CGRectMake(15, 280, self.view.bounds.size.width - 30, 30)];
    albumsHeader.text = @"Recently Added Albums";
    albumsHeader.font = [UIFont boldSystemFontOfSize:18];
    [self.scrollView addSubview:albumsHeader];
    
    self.albumsTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 320, self.view.bounds.size.width, 260) style:UITableViewStylePlain];
    self.albumsTableView.delegate = self;
    self.albumsTableView.dataSource = self;
    self.albumsTableView.tag = 2;
    self.albumsTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.albumsTableView];
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 720);
    [self fetchShows];
    [self fetchAlbums];

}

#pragma mark - Data Fetching

- (void)fetchShows {
    NSLog(@"show fetch time");
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    NSString *urlString = [NSString stringWithFormat:@"%@/Items?IncludeItemTypes=Series&SortBy=DateCreated&SortOrder=Descending&Recursive=true&Limit=5", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if (error) {
                                   NSLog(@"Error fetching shows: %@", error.localizedDescription);
                                   return;
                               }
                               
                               NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                               self.shows = jsonResponse[@"Items"];
                               
                               [self.showsTableView reloadData];
                               NSLog(@"%@", jsonResponse);
                           }];
}

- (void)fetchAlbums {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    NSString *urlString = [NSString stringWithFormat:@"%@/Items?IncludeItemTypes=MusicAlbum&Recursive=true&SortBy=DateCreated&Fields=PrimaryImageAspectRatio,SortName&SortOrder=Descending&Limit=5", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSString *deviceName = [self deviceName];
    NSString *authHeader = [NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.0\", Token=\"%@\"", deviceName, (long)deviceId, token];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if (error) {
                                   NSLog(@"Error fetching albums: %@", error.localizedDescription);
                                   return;
                               }
                               
                               NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];;
                               self.albums = jsonResponse[@"Items"];
                               
                               [self.albumsTableView reloadData];
                           }];
}

- (void)fetchServerData {
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSString *urlString = [NSString stringWithFormat:@"%@/System/Info/Public", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                   return;
                               }
                               
                               if (data) {
                                   NSError *jsonError = nil;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                   
                                   if (jsonError) {
                                       NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
                                       return;
                                   }
                                   
                                   NSString *serverName = jsonResponse[@"ServerName"];
                                   
                                   if (serverName && [serverName isKindOfClass:[NSString class]]) {
                                       self.navigationItem.title = serverName;
                                       NSLog(@"Server Name: %@", serverName);
                                   } else {
                                       NSLog(@"ServerName key not found or invalid.");
                                   }
                               }
                           }];
}

- (void)displayAlertView:(NSString *)title message:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [alert show];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == 1) {
        return self.shows.count;
    } else if (tableView.tag == 2) {
        return self.albums.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *item = (tableView.tag == 1) ? self.shows[indexPath.row] : self.albums[indexPath.row];
    cell.textLabel.text = item[@"Name"];
    cell.detailTextLabel.text = (tableView.tag == 1) ? [NSString stringWithFormat:@"Rated %@ • %@", item[@"OfficialRating"], item[@"ProductionYear"]] : item[@"AlbumArtist"];
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    
    NSString *itemId = item[@"Id"];
    UIImage *cachedImage = self.imageCache[itemId];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    } else {
        BOOL loadImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"image_load_artwork"];
        if (loadImages == YES) {
        NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], itemId];
        NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    self.imageCache[itemId] = image;
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
    if(tableView.tag == 1) {
        //borken ;(((((((((((
    } else if(tableView.tag == 2) {
        NSDictionary *selectedAlbum = self.albums[indexPath.row];
        NSString *albumId = selectedAlbum[@"Id"];
        NSString *albumTitle = selectedAlbum[@"Name"];
        
        AlbumViewController *fifthVC = [[AlbumViewController alloc] init];
        fifthVC.albumId = albumId;
        fifthVC.albumTitle = albumTitle;
        [self.navigationController pushViewController:fifthVC animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
