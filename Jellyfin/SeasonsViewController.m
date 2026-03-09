//
//  SeasonsViewController.m
//  Jellyfin
//
//  Created by bruhdude on 3/9/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "SeasonsViewController.h"
#import "EpisodesViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import "Artwork.h"
#import "AppDelegate.h"
#import "JellyfinClient.h"

@interface SeasonsViewController ()

@property (nonatomic, strong) NSArray *seasons;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation SeasonsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.viewTitle;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshSeasons) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    
    [SVProgressHUD showWithStatus:@"Loading seasons..."];
    
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    [self fetchSeasons];
}

- (void)fetchSeasons {
    [[JellyfinClient sharedClient] getSeasonsForShow:self.showId completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching data: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            [self.refreshControl endRefreshing];
            return;
        }
        
        self.seasons = response[@"Items"];
        if ([self.seasons isKindOfClass:[NSArray class]]) {
            [self.tableView reloadData];
        }
        [self.refreshControl endRefreshing];
        [SVProgressHUD dismiss];
    }];
}

- (void)refreshSeasons {
    [SVProgressHUD showWithStatus:@"Refreshing seasons..."];
    [self fetchSeasons];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.seasons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(tableView) weakTableView = tableView;
    static NSString *cellIdentifier = @"SeasonCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *season = self.seasons[indexPath.row];
    cell.textLabel.text = season[@"Name"];
    cell.imageView.image = [UIImage imageNamed:@"PlaceholderPoster"];
    
    NSString *seasonId = season[@"Id"];
    UIImage *cachedImage = [Artwork loadArtworkForId:seasonId inContext:self.managedObjectContext imageCache:self.imageCache quality:50 size:CGSizeMake(440, 660) completion:^(UIImage *image) {
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
    NSDictionary *selectedSeason = self.seasons[indexPath.row];
    NSString *seasonId = selectedSeason[@"Id"];
    NSString *seasonTitle = selectedSeason[@"Name"];
    
    EpisodesViewController *episodesVC = [[EpisodesViewController alloc] init];
    episodesVC.showId = self.showId;
    episodesVC.seasonId = seasonId;
    episodesVC.viewTitle = seasonTitle;
    [self.navigationController pushViewController:episodesVC animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
