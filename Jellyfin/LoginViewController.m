//
//  LoginViewController.m
//  Jellyfin
//
//  Created by bruhdude on 12/1/24.
//  Copyright (c) 2024 bruhdude. All rights reserved.
//

#import "LoginViewController.h"
#import "HomeViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"
#import "JellyfinClient.h"
#include <sys/sysctl.h>

@interface LoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UILabel *welcomeLabel;
@property (nonatomic, assign) BOOL isQuickConnect;

@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *infoLabel2;
@property (nonatomic, strong) UILabel *codeLabel;
@property (nonatomic, strong) UIButton *authenticateButton;
@property (nonatomic, strong) UIButton *passwordLoginButton;

@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *quickConnectButton;

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
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
    
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"qc_secret"];
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"] == 0) {
        NSLog(@"no device id, generating one");
        int randomDeviceId = arc4random_uniform(1000000);
        [[NSUserDefaults standardUserDefaults] setInteger:randomDeviceId forKey:@"device_id"];
    }
    NSInteger deviceId = [[NSUserDefaults standardUserDefaults] integerForKey:@"device_id"];
    NSLog(@"%ld", (long)deviceId);
    
    self.welcomeLabel = [[UILabel alloc] init];
    self.welcomeLabel.numberOfLines = 0;
    self.welcomeLabel.textAlignment = NSTextAlignmentCenter;
    self.welcomeLabel.text = @"Welcome to Jellyfin for Legacy iOS!\nPlease log in to continue.";
    self.welcomeLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.view addSubview:self.welcomeLabel];
    
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.text = @"Open Jellyfin on another device, go to Settings, open Quick Connect, and enter the code displayed below.";
    [self.view addSubview:self.infoLabel];
    
    self.codeLabel = [[UILabel alloc] init];
    self.codeLabel.numberOfLines = 0;
    self.codeLabel.textAlignment = NSTextAlignmentCenter;
    self.codeLabel.text = @"------";
    [self.view addSubview:self.codeLabel];
    
    self.authenticateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.authenticateButton setTitle:@"Get Code" forState:UIControlStateNormal];
    [self.authenticateButton addTarget:self action:@selector(QuickConnect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.authenticateButton];
    
    self.infoLabel2 = [[UILabel alloc] init];
    self.infoLabel2.numberOfLines = 0;
    self.infoLabel2.textAlignment = NSTextAlignmentCenter;
    self.infoLabel2.text = @"Make sure your instance has Quick Connect enabled!";
    [self.view addSubview:self.infoLabel2];
    
    self.passwordLoginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.passwordLoginButton setTitle:@"Log In with Username & Password" forState:UIControlStateNormal];
    [self.passwordLoginButton addTarget:self action:@selector(showPasswordLogin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.passwordLoginButton];
    
    self.usernameField = [[UITextField alloc] init];
    self.usernameField.placeholder = @"Username";
    self.usernameField.borderStyle = UITextBorderStyleRoundedRect;
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.delegate = self;
    [self.view addSubview:self.usernameField];
    
    self.passwordField = [[UITextField alloc] init];
    self.passwordField.placeholder = @"Password";
    self.passwordField.secureTextEntry = YES;
    self.passwordField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordField.delegate = self;
    [self.view addSubview:self.passwordField];
    
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"Log In" forState:UIControlStateNormal];
    [self.loginButton addTarget:self action:@selector(performLogin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];
    
    self.quickConnectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.quickConnectButton setTitle:@"Log In with Quick Connect" forState:UIControlStateNormal];
    [self.quickConnectButton addTarget:self action:@selector(showQuickConnect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.quickConnectButton];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    self.isQuickConnect = NO;
    [self updateUIState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat padding = 20.0;
    CGFloat currentY = 30.0;
    
    CGSize welcomeSize = [self.welcomeLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
    self.welcomeLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, welcomeSize.height);
    currentY += welcomeSize.height + 20;
    
    if (self.isQuickConnect) {
        CGSize infoSize = [self.infoLabel sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
        self.infoLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, infoSize.height);
        currentY += infoSize.height + 10;
        
        self.codeLabel.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        currentY += 40 + 10;
        
        self.authenticateButton.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        currentY += 40 + 10;
        
        CGSize info2Size = [self.infoLabel2 sizeThatFits:CGSizeMake(width - 2 * padding, CGFLOAT_MAX)];
        self.infoLabel2.frame = CGRectMake(padding, currentY, width - 2 * padding, info2Size.height);
        currentY += info2Size.height + 20;
        
        self.passwordLoginButton.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        
    } else {
        self.usernameField.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        currentY += 40 + 10;
        
        self.passwordField.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        currentY += 40 + 20;
        
        self.loginButton.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
        currentY += 40 + 10;
        
        self.quickConnectButton.frame = CGRectMake(padding, currentY, width - 2 * padding, 40);
    }
    
    self.loadingIndicator.center = CGPointMake(width / 2, self.view.bounds.size.height - 50);
}

- (void)showQuickConnect {
    self.isQuickConnect = YES;
    [self updateUIState];
}

- (void)showPasswordLogin {
    self.isQuickConnect = NO;
    [self updateUIState];
}

- (void)updateUIState {
    BOOL qc = self.isQuickConnect;
    
    self.infoLabel.hidden = !qc;
    self.codeLabel.hidden = !qc;
    self.authenticateButton.hidden = !qc;
    self.infoLabel2.hidden = !qc;
    self.passwordLoginButton.hidden = !qc;
    
    self.usernameField.hidden = qc;
    self.passwordField.hidden = qc;
    self.loginButton.hidden = qc;
    self.quickConnectButton.hidden = qc;
    
    [self.view setNeedsLayout];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
    } else if (textField == self.passwordField) {
        [self.passwordField resignFirstResponder];
        [self performLogin];
    }
    return YES;
}

- (void)performLogin {
    [self dismissKeyboard];
    NSString *username = self.usernameField.text;
    NSString *password = self.passwordField.text;
    
    if (username.length == 0) {
        [self displayAlertView:@"Error" message:@"Please enter a username."];
        return;
    }
    
    [SVProgressHUD showWithStatus:@"Logging In..."];
    [[JellyfinClient sharedClient] authenticateUserByName:username password:password completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"Login error: %@", error.localizedDescription);
            [SVProgressHUD dismiss];
            [self displayAlertView:@"Failed to Log In" message:@"Invalid username or password, or connection error."];
            return;
        }
        
        NSString *token = response[@"AccessToken"];
        NSString *userId = response[@"User"][@"Id"];
        NSString *userName = response[@"User"][@"Name"];
        
        if (token && userId) {
            [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"token"];
            [[NSUserDefaults standardUserDefaults] setObject:userId forKey:@"user_id"];
            if (userName) {
                [[NSUserDefaults standardUserDefaults] setObject:userName forKey:@"username"];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [SVProgressHUD showSuccessWithStatus:@"Logged In"];
            [self transitionToMainInterface];
        } else {
            [SVProgressHUD dismiss];
            [self displayAlertView:@"Error" message:@"Invalid response from server."];
        }
    }];
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
    
    [SVProgressHUD showWithStatus:@"Initiating..."];
    
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
                                       [self.authenticateButton setTitle:@"Status Check" forState:UIControlStateNormal];
                                       [SVProgressHUD dismiss];
                                   }
                               }];
    } else {
        [SVProgressHUD showWithStatus:@"Checking..."];
        
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
                                           [SVProgressHUD showSuccessWithStatus:@"Logged In"];
                                           //we ball
                                           [self logInTime];
                                       } else {
                                           [SVProgressHUD dismiss];
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
                                   NSString *userId = jsonResponse[@"User"][@"Id"];
                                   NSString *userName = jsonResponse[@"User"][@"Name"];
                                   NSLog(@"got token: %@", token);
                                   if(token != nil) {
                                       [[NSUserDefaults standardUserDefaults] setValue:token forKey:@"token"];
                                       if(userId != nil) {
                                           [[NSUserDefaults standardUserDefaults] setValue:userId forKey:@"user_id"];
                                       }
                                       if (userName) {
                                           [[NSUserDefaults standardUserDefaults] setValue:userName forKey:@"username"];
                                       }
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
    dispatch_async(dispatch_get_main_queue(), ^{
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *mainVC = [storyboard instantiateInitialViewController];
        
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        if (!window) {
            window = [[[UIApplication sharedApplication] delegate] window];
        }
        
        window.rootViewController = mainVC;
        
        [UIView transitionWithView:window
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:nil
                        completion:nil];
    });
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