//
//  AppDelegate.m
//  Jellyfin
//
//  Created by Jack on 11/30/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "AppDelegate.h"
#import "LoginViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //[UINavigationBar.appearance setBackgroundImage:[UIImage imageNamed:@"UITitlebarBG"] forBarMetrics:UIBarMetricsDefault];
    // Override point for customization after application launch.
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"] == 0) {
        int randomDeviceId = arc4random_uniform(100000);
        [[NSUserDefaults standardUserDefaults] setInteger:randomDeviceId forKey:@"device_id"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Retrieve the stored token
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"token"];
    
    UIViewController *rootViewController;
    
    if (token == nil || [token isEqualToString:@""]) {
        // No token, instantiate LoginViewController programmatically
        rootViewController = [[LoginViewController alloc] init]; // Assuming you have an init method
    } else {
        // Token exists, instantiate the Main Tab Bar Controller from the storyboard
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        rootViewController = [storyboard instantiateInitialViewController]; // Loads the TabBarController (since it's the initial controller)
    }
    
    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
