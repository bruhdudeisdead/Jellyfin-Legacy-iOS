//
//  MoviesViewController.m
//  Jellyfin
//
//  Created by bruhdude on 11/30/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "MoviesViewController.h"
#import "MovieViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "Artwork.h"
#import "AppDelegate.h"
#import "JellyfinClient.h"

@interface MoviesViewController ()

@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) AVPlayer *audioPlayer;
@property (nonatomic, strong) NSDictionary *selectedMovie2;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation MoviesViewController

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
    NSDictionary *params = @{
                             @"IncludeItemTypes": @"Movie",
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
        
        self.movies = response[@"Items"];
        if ([self.movies isKindOfClass:[NSArray class]]) {
            [self.tableView reloadData];
        }
        [self.refreshControl endRefreshing];
        [SVProgressHUD dismiss];
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
        UIImage *cachedImage = [Artwork loadArtworkForId:movieId inContext:self.managedObjectContext imageCache:self.imageCache quality:80 size:CGSizeMake(440, 660) completion:^(UIImage *image) {
            UITableViewCell *updateCell = [weakTableView cellForRowAtIndexPath:indexPath];
            if (updateCell) {
                updateCell.imageView.image = image;
                [updateCell setNeedsLayout];
            }
        }];
        
        if (cachedImage) {
            cell.imageView.image = cachedImage;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *selectedMovie = self.movies[indexPath.row];
    NSString *movieId = selectedMovie[@"Id"];
    
    [SVProgressHUD showWithStatus:@"Loading..."];
    
    [[JellyfinClient sharedClient] getItem:movieId completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Error fetching data: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            return;
        }
        
        self.selectedMovie2 = response;
        
        __block UIImage *posterImage = [UIImage imageNamed:@"placeholder"];
        
        [Artwork loadArtworkForId:movieId inContext:self.managedObjectContext imageCache:self.imageCache quality:90 size:CGSizeZero completion:^(UIImage *image) {
            if (image) {
                posterImage = image;
            }
            MovieViewController *movieVC = [[MovieViewController alloc] init];
            movieVC.movieId = selectedMovie[@"Id"];
            movieVC.moviePoster = posterImage;
            movieVC.movieTitle = self.selectedMovie2[@"Name"];
            if ([self.selectedMovie2[@"Taglines"] count] > 0) {
                movieVC.movieTagline = self.selectedMovie2[@"Taglines"][0];
            }
            movieVC.movieProductionYear = self.selectedMovie2[@"ProductionYear"];
            movieVC.movieOverview = self.selectedMovie2[@"Overview"];
            
            [self.navigationController pushViewController:movieVC animated:YES];
            [SVProgressHUD dismiss];
        }];
        
        UIImage *syncImage = [Artwork loadArtworkForId:movieId inContext:self.managedObjectContext imageCache:self.imageCache quality:90 size:CGSizeZero completion:^(UIImage *image) {
            posterImage = image;
            [self pushMovieVC:selectedMovie poster:posterImage];
        }];
        
        if (syncImage) {
            posterImage = syncImage;
            [self pushMovieVC:selectedMovie poster:posterImage];
        }
        
    }];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushMovieVC:(NSDictionary *)selectedMovie poster:(UIImage *)posterImage {
    MovieViewController *movieVC = [[MovieViewController alloc] init];
    movieVC.movieId = selectedMovie[@"Id"];
    movieVC.moviePoster = posterImage;
    movieVC.movieTitle = self.selectedMovie2[@"Name"];
    if ([self.selectedMovie2[@"Taglines"] count] > 0) {
        movieVC.movieTagline = self.selectedMovie2[@"Taglines"][0];
    }
    movieVC.movieProductionYear = self.selectedMovie2[@"ProductionYear"];
    movieVC.movieOverview = self.selectedMovie2[@"Overview"];
    
    [self.navigationController pushViewController:movieVC animated:YES];
    [SVProgressHUD dismiss];
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

