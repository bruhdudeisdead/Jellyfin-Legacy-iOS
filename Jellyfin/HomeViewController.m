//
//  HomeViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "HomeViewController.h"
#import "AlbumViewController.h"
#import "SeasonsViewController.h"
#import "Artwork.h"
#import "AppDelegate.h"
#import "JellyfinClient.h"
#import "ProfileViewController.h"

@interface HomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *showsHeaderLabel;
@property (nonatomic, strong) UITableView *showsTableView;
@property (nonatomic, strong) UILabel *albumsHeaderLabel;
@property (nonatomic, strong) UITableView *albumsTableView;
@property (nonatomic, strong) NSArray *shows;
@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"] ?: @"Profile";
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:username style:UIBarButtonItemStyleBordered target:self action:@selector(openSettings)];
    self.navigationItem.leftBarButtonItem = settingsButton;
    
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
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    self.showsHeaderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.showsHeaderLabel.text = @"Recently Added TV Shows";
    self.showsHeaderLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.scrollView addSubview:self.showsHeaderLabel];
    
    self.showsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.showsTableView.delegate = self;
    self.showsTableView.dataSource = self;
    self.showsTableView.tag = 1;
    [self.scrollView addSubview:self.showsTableView];
    
    self.albumsHeaderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.albumsHeaderLabel.text = @"Recently Added Albums";
    self.albumsHeaderLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.scrollView addSubview:self.albumsHeaderLabel];
    
    self.albumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.albumsTableView.delegate = self;
    self.albumsTableView.dataSource = self;
    self.albumsTableView.tag = 2;
    [self.scrollView addSubview:self.albumsTableView];
    
    [self fetchShows];
    [self fetchAlbums];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat padding = 15.0;
    CGFloat currentY = 10.0;
    CGFloat headerHeight = 30.0;
    CGFloat tableHeight = 260.0;
    
    self.showsHeaderLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, headerHeight);
    currentY += headerHeight + 10;
    
    self.showsTableView.frame = CGRectMake(0, currentY, width, tableHeight);
    currentY += tableHeight + 20;
    
    self.albumsHeaderLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, headerHeight);
    currentY += headerHeight + 10;
    
    self.albumsTableView.frame = CGRectMake(0, currentY, width, tableHeight);
    currentY += tableHeight + 20;
    
    self.scrollView.contentSize = CGSizeMake(width, currentY);
}

#pragma mark - Data Fetching

- (void)fetchShows {
    NSLog(@"show fetch time");
    
    NSDictionary *params = @{
                             @"IncludeItemTypes": @"Series",
                             @"SortBy": @"DateCreated",
                             @"SortOrder": @"Descending",
                             @"Recursive": @"true",
                             @"Limit": @"5"
                             };
    
    [[JellyfinClient sharedClient] getItemsWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching shows: %@", error.localizedDescription);
            return;
        }
        
        self.shows = response[@"Items"];
        [self.showsTableView reloadData];
        NSLog(@"%@", response);
    }];
}

- (void)fetchAlbums {
    NSDictionary *params = @{
                             @"IncludeItemTypes": @"MusicAlbum",
                             @"Recursive": @"true",
                             @"SortBy": @"DateCreated",
                             @"Fields": @"PrimaryImageAspectRatio,SortName",
                             @"SortOrder": @"Descending",
                             @"Limit": @"5"
                             };
    
    [[JellyfinClient sharedClient] getItemsWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching albums: %@", error.localizedDescription);
            return;
        }
        
        self.albums = response[@"Items"];
        [self.albumsTableView reloadData];
    }];
}

- (void)fetchServerData {
    [[JellyfinClient sharedClient] getServerInfoWithCompletion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching data: %@", error.localizedDescription);
            return;
        }
        
        NSString *serverName = response[@"ServerName"];
        
        if (serverName && [serverName isKindOfClass:[NSString class]]) {
            self.navigationItem.title = serverName;
            NSLog(@"Server Name: %@", serverName);
        } else {
            NSLog(@"ServerName key not found or invalid.");
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
    __weak typeof(tableView) weakTableView = tableView;
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *item = (tableView.tag == 1) ? self.shows[indexPath.row] : self.albums[indexPath.row];
    cell.textLabel.text = item[@"Name"];
    cell.detailTextLabel.text = (tableView.tag == 1) ? [NSString stringWithFormat:@"Rated %@ • %@", item[@"OfficialRating"], item[@"ProductionYear"]] : item[@"AlbumArtist"];
    cell.imageView.image = (tableView.tag == 1) ? [UIImage imageNamed:@"PlaceholderPoster"] : [UIImage imageNamed:@"PlaceholderCover"];
    
    NSString *itemId = item[@"Id"];
    UIImage *cachedImage = [Artwork loadArtworkForId:itemId inContext:self.managedObjectContext imageCache:self.imageCache quality:50 size:CGSizeZero completion:^(UIImage *image) {
        UITableViewCell *updateCell = [weakTableView cellForRowAtIndexPath:indexPath];
        if (updateCell) {
            updateCell.imageView.image = image;
            [updateCell setNeedsLayout];
        }
    }];
    
    if (cachedImage) {
        cell.imageView.image = cachedImage;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(tableView.tag == 1) {
        //borken ;(((((((((((
        NSDictionary *selectedShow = self.shows[indexPath.row];
        NSString *showId = selectedShow[@"Id"];
        NSString *showTitle = selectedShow[@"Name"];
        
        SeasonsViewController *seasonsVC = [[SeasonsViewController alloc] init];
        seasonsVC.showId = showId;
        seasonsVC.viewTitle = showTitle;
        [self.navigationController pushViewController:seasonsVC animated:YES];
    } else if(tableView.tag == 2) {
        NSDictionary *selectedAlbum = self.albums[indexPath.row];
        NSString *albumId = selectedAlbum[@"Id"];
        NSString *albumTitle = selectedAlbum[@"Name"];
        
        AlbumViewController *albumVC = [[AlbumViewController alloc] init];
        albumVC.albumId = albumId;
        albumVC.albumTitle = albumTitle;
        [self.navigationController pushViewController:albumVC animated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openSettings {
    ProfileViewController *settingsVC = [[ProfileViewController alloc] init];
    settingsVC.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
