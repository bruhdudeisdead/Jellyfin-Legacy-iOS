//
//  AlbumViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "AlbumViewController.h"
#import "NowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "SVProgressHUD/SVProgressHUD.h"
#import "JellyfinClient.h"
#include <sys/sysctl.h>

@interface AlbumViewController ()

@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@end

@implementation AlbumViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.albumTitle;
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshMusic) forControlEvents:UIControlEventValueChanged];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.tableView addSubview:self.refreshControl];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 150, 0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    [SVProgressHUD showWithStatus:@"Loading music..."];
    [self fetchMusic];
}

- (void)fetchMusic {
    NSDictionary *params = @{
                             @"ParentId": self.albumId,
                             @"SortBy": @"ParentIndexNumber,IndexNumber,SortName",
                             @"Fields": @"ItemCounts,PrimaryImageAspectRatio,CanDelete,MediaSourceCount",
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
    static NSString *cellIdentifier = @"AlbumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *song = self.music[indexPath.row];
    cell.textLabel.text = song[@"Name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", song[@"Artists"][0], song[@"Album"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *songList = [NSMutableArray array];
    for (NSDictionary *song in self.music) {
        [songList addObject:@{
                              @"Id": song[@"Id"],
                              @"Name": song[@"Name"],
                              @"Artist": song[@"Artists"][0],
                              @"Album": song[@"Album"]
                              }];
    }
    
    NSDictionary *selectedSong = self.music[indexPath.row];
    NSString *songId = selectedSong[@"Id"];
    NSString *coverUrlString = [NSString stringWithFormat:@"%@/Items/%@/Images/Primary", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], songId];
    NSURL *coverUrl = [NSURL URLWithString:coverUrlString];
    NSURL *songUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/Audio/%@/stream?static=true", [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"], songId]];
    
    __block UIImage *coverImage = [UIImage imageNamed:@"PlaceholderCover"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:coverUrl];
        if (imageData) {
            coverImage = [UIImage imageWithData:imageData];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NowPlayingViewController *nowPlayingVC = [[NowPlayingViewController alloc] init];
            nowPlayingVC.songList = songList;
            nowPlayingVC.currentIndex = indexPath.row;
            
            nowPlayingVC.songURL = songUrl;
            nowPlayingVC.albumArt = coverImage;
            nowPlayingVC.songTitle = selectedSong[@"Name"];
            nowPlayingVC.artistName = selectedSong[@"Artists"][0];
            nowPlayingVC.albumName = selectedSong[@"Album"];
            
            [self.navigationController pushViewController:nowPlayingVC animated:YES];
        });
    });
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)audioPlayerDidFinish:(NSNotification *)notification {
    NSLog(@"Audio playback finished");
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.audioPlayer = nil;
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


