//
//  LoginViewController.m
//  Jellyfin
//
//  Created by bruhdude on 12/1/24.
//  Copyright (c) 2024 DumbStupidStuff. All rights reserved.
//

#import "LoginViewController.h"
#import "HomeViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#include <sys/sysctl.h>

@interface LoginViewController ()

@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *infoLabel2;
@property (nonatomic, strong) UILabel *codeLabel;
@property (nonatomic, strong) UIButton *authenticateButton;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation LoginViewController

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
    NSString *deviceName = [self deviceName];
    NSLog(@"Device: %@", deviceName);
    self.view.backgroundColor = [UIColor whiteColor];
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"qc_secret"];
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"] == 0) {
        NSLog(@"no device id, generating one");
        int randomDeviceId = arc4random_uniform(1000000);
        [[NSUserDefaults standardUserDefaults] setInteger:randomDeviceId forKey:@"device_id"];
    }
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSLog(@"%ld", (long)deviceId);
    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.frame.size.width - 40, 100)];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.text = @"To log in, open Jellyfin on another device, go to Settings, open Quick Connect, and enter the code displayed below.";
    [self.view addSubview:self.infoLabel];
    
    self.codeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 170, self.view.frame.size.width - 40, 100)];
    self.codeLabel.numberOfLines = 0;
    self.codeLabel.textAlignment = NSTextAlignmentCenter;
    self.codeLabel.text = @"------";
    [self.view addSubview:self.codeLabel];
    
    self.authenticateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.authenticateButton.frame = CGRectMake(20, 260, self.view.frame.size.width - 40, 40);
    [self.authenticateButton setTitle:@"Get Code" forState:UIControlStateNormal];
    [self.authenticateButton addTarget:self action:@selector(QuickConnect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.authenticateButton];
    
    self.infoLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 300, self.view.frame.size.width - 40, 100)];
    self.infoLabel2.numberOfLines = 0;
    self.infoLabel2.textAlignment = NSTextAlignmentCenter;
    self.infoLabel2.text = @"Make sure your instance has Quick Connect enabled!";
    [self.view addSubview:self.infoLabel2];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.center = CGPointMake(self.view.center.x, 400);
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
}

- (void)QuickConnect {
    NSString *deviceName = [self deviceName];
    NSLog(@"Device: %@", deviceName);
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSLog(@"device ID: %ld", (long)deviceId);
    NSLog(@"server URL: %@", serverUrl);
    if (!serverUrl || !deviceId) {
        NSLog(@"Server URL or device id is missing.");
        [self displayAlertView:@"Missing Values" message:@"Your instance URL or device ID cannot be found. You most likely forgot to put in your instance URL in Settings. If this is not the case, please contact bruhdude."];
        [SVProgressHUD dismiss];
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/QuickConnect/Initiate", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.2.1\"", deviceName, (long)deviceId] forHTTPHeaderField:@"Authorization"];
    if([[NSUserDefaults standardUserDefaults] stringForKey:@"qc_secret"] == nil) {
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   if (connectionError) {
                                       NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                       [SVProgressHUD dismiss];
                                       return;
                                   }
                                   if (data) {
                                       NSError *jsonError = nil;
                                       NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                       if (jsonError) {
                                           NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
                                           [SVProgressHUD dismiss];
                                           return;
                                       }
                                       NSLog(@"%@", jsonResponse);
                                       
                                       self.secret = jsonResponse[@"Secret"];
                                       NSLog(@"got secret: %@", self.secret);
                                       if(self.secret != nil) {
                                           if([[NSUserDefaults standardUserDefaults] stringForKey:@"qc_secret"] == nil) {
                                               [[NSUserDefaults standardUserDefaults] setValue:self.secret forKey:@"qc_secret"];
                                           } else {
                                           }
                                       }
                                       
                                       NSNumber *codeN = jsonResponse[@"Code"];
                                       NSInteger code = [codeN integerValue];
                                       NSLog(@"got code: %ld", (long)code);
                                       
                                       self.codeLabel.text = [NSString stringWithFormat:@"%ld", (long)code];
                                       [self.authenticateButton setTitle:@"Authentication Check" forState:UIControlStateNormal];
                                   }
                               }];
    } else {
        NSString *shit = [[NSUserDefaults standardUserDefaults] stringForKey:@"qc_secret"];
        NSString *urlString = [NSString stringWithFormat:@"%@/QuickConnect/Connect?Secret=%@", serverUrl, shit];
        NSURL *url = [NSURL URLWithString:urlString];
        NSLog(@"%@", urlString);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:[NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.3\"", deviceName, (long)deviceId] forHTTPHeaderField:@"Authorization"];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   if (connectionError) {
                                       NSLog(@"Error fetching data: %@", connectionError.localizedDescription);
                                       [SVProgressHUD dismiss];
                                       return;
                                   }
                                   if (data) {
                                       NSError *jsonError = nil;
                                       NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                                       if (jsonError) {
                                           NSLog(@"Error parsing JSON2: %@", jsonError.localizedDescription);
                                           NSLog(@"%@", [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError]);
                                           [SVProgressHUD dismiss];
                                           //just goign to assume that secret expired cause of this response...
                                           [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"qc_secret"];
                                           return;
                                       }
                                       NSLog(@"%@", jsonResponse);
                                       NSNumber *authenticatedNumber = jsonResponse[@"Authenticated"];
                                       if ([authenticatedNumber isKindOfClass:[NSNumber class]]) {
                                           NSInteger authenticated = [authenticatedNumber integerValue];
                                           NSLog(@"got secret: %ld", (long)authenticated);
                                       } else {
                                           NSLog(@"'Authenticated' is not a valid number.");
                                       }
                                       NSInteger authenticated = [authenticatedNumber integerValue];
                                       if(authenticated == 1) {
                                           //we ball
                                           UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Authenticated" message:@"You have been successfully authenticated! Restart the app to continue." delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
                                           [alert show];
                                           [self logInTime];
                                       } else {
                                           [self displayAlertView:@"Not Authenticated" message:@"Follow the instructions above the code."];
                                       }
                                   }
                               }];
    }
}
- (void)logInTime {
    NSString *deviceName = [self deviceName];
    NSLog(@"Device: %@", deviceName);
    NSString *serverUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"server_url"];
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSLog(@"device ID: %ld", (long)deviceId);
    NSLog(@"server URL: %@", serverUrl);
    if (!serverUrl || !deviceId) {
        NSLog(@"Server URL or device id is missing.");
        [self displayAlertView:@"Missing Values" message:@"Your instance URL or device ID cannot be found. You most likely forgot to put in your instance URL in Settings."];
        [SVProgressHUD dismiss];
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/Users/AuthenticateWithQuickConnect", serverUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    [request setValue:[NSString stringWithFormat:@"MediaBrowser Client=\"Jellyfin for Legacy iOS\", Device=\"%@\", DeviceId=\"%ld\", Version=\"1.2.1\"", deviceName, (long)deviceId] forHTTPHeaderField:@"Authorization"];
    
    NSString *qcSecret = [[NSUserDefaults standardUserDefaults] stringForKey:@"qc_secret"];
    if (!qcSecret) {
        NSLog(@"Error: Quick connect secret not found in user defaults.");
        [self displayAlertView:@"s" message:@"Error: Quick connect secret not found in user defaults."];
        return;
    }
    
    NSDictionary *jsonBody = @{@"Secret": qcSecret};
    NSError *jsonError;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&jsonError];
    
    if (jsonError) {
        NSLog(@"Error creating JSON body: %@", jsonError.localizedDescription);
        [self displayAlertView:@"JSON Error" message:@"Something is very wrong."];
        return;
    }
    
    request.HTTPBody = bodyData;
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   NSLog(@"Error: %@", connectionError.localizedDescription);
                                   [SVProgressHUD dismiss];
                                   return;
                               }
                               if (data) {
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                   NSLog(@"Response JSON: %@", jsonResponse);
                                   NSString *token = jsonResponse[@"AccessToken"];
                                   NSLog(@"got token: %@", token);
                                   if(token != nil) {
                                       [[NSUserDefaults standardUserDefaults] setValue:token forKey:@"token"];
                                       [[NSUserDefaults standardUserDefaults] synchronize];
                                       [self transitionToMainInterface];
                                   } else {
                                       [self displayAlertView:@"Invalid Token" message:@"Something is very wrong."];
                                   }
                               }
                           }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)transitionToMainInterface {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)displayAlertView:(NSString *)title message:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end