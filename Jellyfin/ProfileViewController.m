//
//  ProfileViewController.m
//  Jellyfin
//
//  Created by bruhdude on 3/7/26.
//  Copyright (c) 2026 bruhdude. All rights reserved.
//

#import "ProfileViewController.h"
#import "JellyfinClient.h"
#import "LoginViewController.h"
#import "AppDelegate.h"

@interface ProfileViewController ()

@property (nonatomic, strong) UIImageView *profileImageView;
@property (nonatomic, strong) UILabel *usernameLabel;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation ProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Settings";
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.translucent = NO;
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSettings)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    self.profileImageView = [[UIImageView alloc] init];
    self.profileImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.profileImageView.clipsToBounds = YES;
    self.profileImageView.layer.cornerRadius = 50;
    self.profileImageView.layer.borderWidth = 2.0;
    self.profileImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.profileImageView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:self.profileImageView];
    
    self.usernameLabel = [[UILabel alloc] init];
    self.usernameLabel.textAlignment = NSTextAlignmentCenter;
    self.usernameLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.view addSubview:self.usernameLabel];
    
    self.logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.logoutButton setTitle:@"Log Out" forState:UIControlStateNormal];
    [self.logoutButton addTarget:self action:@selector(logout) forControlEvents:UIControlEventTouchUpInside];
    
    BOOL isiOS7OrLater = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
    
    if (isiOS7OrLater) {
        [self.logoutButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        self.logoutButton.layer.borderColor = [UIColor redColor].CGColor;
        self.logoutButton.layer.borderWidth = 1.0;
        self.logoutButton.layer.cornerRadius = 5.0;
    }
    
    self.logoutButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.view addSubview:self.logoutButton];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.center = self.view.center;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    [self fetchUserProfile];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat startY = 20;
    
    if (self.navigationController && !self.navigationController.navigationBarHidden) {
        if (!self.navigationController.navigationBar.translucent) {
            startY = 20;
        } else {
            startY = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height + 20;
        }
    }
    
    self.profileImageView.frame = CGRectMake((width - 100) / 2, startY, 100, 100);
    startY += 100 + 20;
    
    self.usernameLabel.frame = CGRectMake(20, startY, width - 40, 30);
    startY += 30 + 40;
    
    self.logoutButton.frame = CGRectMake(20, startY, width - 40, 44);
    
    self.loadingIndicator.center = self.view.center;
}

- (void)dismissSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)fetchUserProfile {
    [self.loadingIndicator startAnimating];
    NSString *userId = [[NSUserDefaults standardUserDefaults] stringForKey:@"user_id"];
    
    if (!userId) {
        self.usernameLabel.text = @"No User ID";
        [self.loadingIndicator stopAnimating];
        return;
    }
    
    [[JellyfinClient sharedClient] getUser:userId completion:^(NSDictionary *response, NSError *error) {
        [self.loadingIndicator stopAnimating];
        if (error) {
            NSLog(@"Error fetching user profile: %@", error.localizedDescription);
            self.usernameLabel.text = @"Unknown User";
            return;
        }
        
        NSString *username = response[@"Name"];
        self.usernameLabel.text = username;
        
        NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
        NSString *imageUrlString = [NSString stringWithFormat:@"%@/Users/%@/Images/Primary", serverUrl, userId];
        NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
        [request setValue:[[JellyfinClient sharedClient] authHeader] forHTTPHeaderField:@"Authorization"];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            if (data) {
                self.profileImageView.image = [UIImage imageWithData:data];
            }
        }];
    }];
}

- (void)logout {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"token"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"user_id"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    UIWindow *window = appDelegate.window;
    
    LoginViewController *loginVC = [[LoginViewController alloc] init];
    
    [UIView transitionWithView:window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        window.rootViewController = loginVC;
                    }
                    completion:nil];
}

@end
