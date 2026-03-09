//
//  TVShowsViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "TVShowsViewController.h"
#import "SeasonsViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "Artwork.h"
#import "AppDelegate.h"
#import "JellyfinClient.h"

@interface TVShowsViewController ()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation TVShowsViewController

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
    NSDictionary *params = @{
                             @"IncludeItemTypes": @"Series",
                             @"Recursive": @"true",
                             @"SortBy": @"Name",
                             @"SortOrder": @"Ascending"
                             };
    
    [[JellyfinClient sharedClient] getItemsWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching data: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            [self.refreshControl endRefreshing];
            return;
        }
        
        self.shows = response[@"Items"];
        if ([self.shows isKindOfClass:[NSArray class]]) {
            [self.tableView reloadData];
        }
        [self.refreshControl endRefreshing];
        [SVProgressHUD dismiss];
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
    UIImage *cachedImage = [Artwork loadArtworkForId:showId inContext:self.managedObjectContext imageCache:self.imageCache quality:50 size:CGSizeMake(440, 660) completion:^(UIImage *image) {
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

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *selectedShow = self.shows[indexPath.row];
    NSString *showId = selectedShow[@"Id"];
    NSString *showTitle = selectedShow[@"Name"];
    
    SeasonsViewController *seasonsVC = [[SeasonsViewController alloc] init];
    seasonsVC.showId = showId;
    seasonsVC.viewTitle = showTitle;
    [self.navigationController pushViewController:seasonsVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
