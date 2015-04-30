//
//  ViewController.m
//  Bookselves-App
//
//  Created by Junyu Wang on 4/28/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import "ViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "constants.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet FBSDKLoginButton *facebookLoginButton;
@property (weak, nonatomic) IBOutlet UIButton *normalUserLogoutButton;
@property (weak, nonatomic) IBOutlet UILabel *userEmailLabel;

@end

@implementation ViewController

#pragma mark - view life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedAccessTokenChangeHandler)
                                                 name:FBSDKAccessTokenDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedProfileChangeHandler)
                                                 name:FBSDKProfileDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedEmailUserIdChangeHandler:)
                                                 name:@"EmailUserIdChangeNotification"
                                               object:nil];
    
    if ([FBSDKAccessToken currentAccessToken]) {
        [self.userNameLabel setText:[NSString stringWithFormat:@"Name: %@", [FBSDKProfile currentProfile].name]];
        
        //hide normal log out button
        self.normalUserLogoutButton.hidden = YES;
        
        //should always be no since the user must have logged in and created a user in the server
        [self fetchUserInfoFromFBandUpdateUIandShouldCreateUserInServer:NO];
    }else {
        //hider fb log out button
        NSLog(@"imhere");
        
        self.facebookLoginButton.hidden = YES;
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"username"] && [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]) {
            [self.userEmailLabel setText:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"]];
            [self.userNameLabel setText:@"Email User"];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if ([FBSDKAccessToken currentAccessToken]) {
        //do something
    }else {
        //if is email user then display otherwise back to login screen
        if ([self.userEmailLabel.text isEqualToString:@"Email:"]) {
           [self performSegueWithIdentifier:@"pop up login view" sender:self];
        }
    }
}

#pragma mark - user log out

- (IBAction)normalUserLogoutButtonHandler:(id)sender {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"username"] && [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]) {
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"password"];
        
        [self performSegueWithIdentifier:@"pop up login view" sender:self];
    }
}


#pragma mark - notification handler

- (void) observedAccessTokenChangeHandler
{
    if (![FBSDKAccessToken currentAccessToken]) {
        [self performSegueWithIdentifier:@"pop up login view" sender:self];
        [self.userNameLabel setText:@"Guest"];
        [self.userEmailLabel setText:@"Unknown"];
    }else {
        [self displayUserProfile];
        
        self.facebookLoginButton.hidden = NO;
        self.normalUserLogoutButton.hidden = YES;
        
        //need a method to verify fb user's existence and then determine the bool value here
        [self fetchUserInfoFromFBandUpdateUIandShouldCreateUserInServer:NO];
    }
}

- (void) observedProfileChangeHandler
{
    if ([FBSDKProfile currentProfile]) {
        [self displayUserProfile];
    }
    
}

- (void)observedEmailUserIdChangeHandler:(NSNotification*)emailUserIdChangeNotificiation
{
    NSDictionary *emailUserId = [emailUserIdChangeNotificiation userInfo];
    NSString* getUserInfoServerReply = [self sendRequestToURL:[NSString stringWithFormat:@"%@/user/%@", serverURL, emailUserId[@"success"]]
                  withData:nil
                withMethod:@"GET"];
    NSLog(getUserInfoServerReply);
    
    NSDictionary* emailUserInfoDictionary = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[getUserInfoServerReply dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    if (emailUserInfoDictionary[@"error"] == nil) {
        
        self.facebookLoginButton.hidden = YES;
        self.normalUserLogoutButton.hidden = NO;
        
        [self updateUIwithUserInfo:emailUserInfoDictionary[@"success"]];
    }else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                   message:emailUserInfoDictionary[@"error"]
                                  delegate:nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark - update UI

- (void) displayUserProfile
{
    NSString *name = [NSString stringWithFormat:@"Name: %@", [FBSDKProfile currentProfile].name];
    self.userNameLabel.text = name;
}

- (void) updateUIwithUserInfo:(NSDictionary*)userInfo
{
    if ([FBSDKAccessToken currentAccessToken]) {
        [self.userEmailLabel setText:userInfo[@"email"]];
    }else {
        NSLog(userInfo[@"username"]);
        [self.userEmailLabel setText:userInfo[@"username"]];
        [self.userNameLabel setText:@"Email User"];
    }
}

#pragma mark - fetch user info from FB / create User in server

- (void) fetchUserInfoFromFBandUpdateUIandShouldCreateUserInServer:(BOOL)should
{
    if ([FBSDKAccessToken currentAccessToken]) {
        FBSDKGraphRequest *graphRequest = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:nil];
        [graphRequest startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (!error) {
                NSLog(@"%@",result);
                NSString *facebookID = [NSString stringWithFormat:@"%@", result[@"id"]];
                if (should) {
                    [self performSelectorOnMainThread:@selector(createUserInServerWithFacebookID:) withObject:facebookID waitUntilDone:NO];
                }
                [self performSelectorOnMainThread:@selector(updateUIwithUserInfo:) withObject:result waitUntilDone:NO];
            }
        }];
    }
}


//something went wrong here when trying to create a user w/ facebook_id and auth_token in the server.
- (void) createUserInServerWithFacebookID:(NSString*) facebookID
{
    if ([FBSDKAccessToken currentAccessToken]) {
        NSString *facebookAccessToken = [NSString stringWithFormat:@"%@", [FBSDKAccessToken currentAccessToken]];
        //NSLog(facebookAccessToken);
        
        NSDictionary *fbLoginData = [[NSDictionary alloc] initWithObjectsAndKeys:facebookID, @"facebook_id", facebookAccessToken, @"auth_token", nil];
        NSString *fbLoginServerReply = [self sendRequestToURL:[NSString stringWithFormat:@"%@/user/create", serverURL]
                      withData:fbLoginData
                    withMethod:@"POST"];
        
        NSLog(@"server reply: %@",fbLoginServerReply);
    }
}


//duplicated code from LoginViewController
#pragma mark - formatize URL

//will be used for verification
- (NSString*) appendEncodedDictionary:(NSDictionary*)dictionary ToURL:(NSString*)url
{
    return [url stringByAppendingString:[NSString stringWithFormat:@"%@", [self turnDictionaryIntoParamsOfURL:dictionary]]];
}

- (NSString *) turnDictionaryIntoParamsOfURL:(NSDictionary*)dictionary
{
    
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (NSString *key in dictionary)
    {
        NSString *encodedValue = [[dictionary objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *part = [NSString stringWithFormat: @"%@=%@", encodedKey, encodedValue];
        [parts addObject:part];
    }
    NSString *encodedDictionary = [parts componentsJoinedByString:@"&"];
    return encodedDictionary;
}

- (NSData*)encodeDictionary:(NSDictionary*)dictionary
{
    NSString *encodedDictionary = [self turnDictionaryIntoParamsOfURL:dictionary];
    //NSLog(encodedDictionary);
    return [encodedDictionary dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)sendRequestToURL:(NSString *)url withData:(NSDictionary *)data withMethod: (NSString *)method
{
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    [urlRequest setHTTPMethod:method];
    NSData *httpData = [self encodeDictionary:data];
    [urlRequest setHTTPBody:httpData];
    NSHTTPURLResponse *response;
    NSError *error;
    NSData* result = [NSURLConnection sendSynchronousRequest:urlRequest  returningResponse:&response error:&error];
    if([response statusCode] >= 400 || [response statusCode] == 0)
    {
        NSLog(@"error: %@", [error description]);
        return nil;
    }
    return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}





@end
