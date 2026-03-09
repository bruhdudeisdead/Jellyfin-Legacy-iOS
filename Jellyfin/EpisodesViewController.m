//
//  EpisodesViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "EpisodesViewController.h"
#import "EpisodeDetailViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import "Artwork.h"
#import "AppDelegate.h"
#import "JellyfinClient.h"

@interface EpisodesViewController ()

@property (nonatomic, strong) NSArray *episodes;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation EpisodesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
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
    
    [SVProgressHUD showWithStatus:@"Loading episodes..."];
    [self fetchEpisodes];
}

- (void)fetchEpisodes {
    [[JellyfinClient sharedClient] getEpisodesForShow:self.showId seasonId:self.seasonId completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching episodes: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            [self.refreshControl endRefreshing];
            return;
        }
        
        self.episodes = response[@"Items"];
        [self.tableView reloadData];
        [SVProgressHUD dismiss];
        [self.refreshControl endRefreshing];
    }];
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
    cell.textLabel.text = [NSString stringWithFormat:@"%@. %@", episode[@"IndexNumber"], episode[@"Name"]];
    NSString *runTimeText = @"";
    NSNumber *runTimeTicks = episode[@"RunTimeTicks"];
    if (runTimeTicks && ![runTimeTicks isKindOfClass:[NSNull class]]) {
        long long ticks = [runTimeTicks longLongValue];
        long long totalSeconds = ticks / 10000000;
        long long hours = totalSeconds / 3600;
        long long minutes = (totalSeconds % 3600) / 60;
        
        if (hours > 0) {
            runTimeText = [runTimeText stringByAppendingFormat:@"%lldh %lldm", hours, minutes];
        } else {
            runTimeText = [runTimeText stringByAppendingFormat:@"%lldm", minutes];
        }
    }
    cell.detailTextLabel.text = runTimeText;
    cell.imageView.image = [UIImage imageNamed:@"PlaceholderPoster"];
    
    NSString *episodeId = episode[@"Id"];
    UIImage *cachedImage = [Artwork loadArtworkForId:episodeId inContext:self.managedObjectContext imageCache:self.imageCache quality:50 size:CGSizeMake(640, 360) completion:^(UIImage *image) {
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

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *episode = self.episodes[indexPath.row];
    
    EpisodeDetailViewController *detailVC = [[EpisodeDetailViewController alloc] init];
    detailVC.episode = episode;
    detailVC.viewTitle = episode[@"Name"];
    [self.navigationController pushViewController:detailVC animated:YES];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
