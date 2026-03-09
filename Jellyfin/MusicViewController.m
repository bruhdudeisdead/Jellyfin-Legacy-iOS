//
//  MusicViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "MusicViewController.h"
#import "AlbumViewController.h"
#import "AppDelegate.h"
#import "NowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "SVProgressHUD/SVProgressHUD.h"
#import "Artwork.h"
#import "JellyfinClient.h"

@interface MusicViewController ()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation MusicViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageCache = [[NSCache alloc] init];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
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
    NSDictionary *params = @{
                             @"IncludeItemTypes": @"MusicAlbum",
                             @"Recursive": @"true",
                             @"SortBy": @"SortName",
                             @"Fields": @"PrimaryImageAspectRatio,SortName",
                             @"SortOrder": @"Ascending",
                             };
    
    [[JellyfinClient sharedClient] getItemsWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching data: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            [self.refreshControl endRefreshing];
            return;
        }
        
        self.music = response[@"Items"];
        if([self.music isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                [self.refreshControl endRefreshing];
                [self.tableView reloadData];
            });
        }
        [self.refreshControl endRefreshing];
        [SVProgressHUD dismiss];
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
    __weak typeof(tableView) weakTableView = tableView;

    static NSString *cellIdentifier = @"AlbumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *song = self.music[indexPath.row];
    cell.textLabel.text = song[@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", song[@"AlbumArtist"], song[@"ProductionYear"]];
    cell.imageView.image = [UIImage imageNamed:@"PlaceholderCover"];
    NSString *songId = song[@"Id"];
    
    ArtworkCache *cachedArtwork = [Artwork fetchArtworkForId:songId inContext:self.managedObjectContext];
    if (cachedArtwork) {
        UIImage *image = [UIImage imageWithData:cachedArtwork.imageData];
        if (image) {
            [self.imageCache setObject:image forKey:songId];
            cell.imageView.image = image;
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSString *imageUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], songId];
            NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
            NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                if (image) {
                    [self.imageCache setObject:image forKey:songId];
                    
                    [Artwork saveArtworkInBackground:imageData forId:songId mainContext:self.managedObjectContext completion:nil];
                    
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
