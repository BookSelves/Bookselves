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
#import "CoreLocation/CoreLocation.h"
#import <INTULocationManager/INTULocationManager.h>
#import <QBImagePickerController/QBImagePickerController.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *normalUserLogoutButton;
@property (weak, nonatomic) IBOutlet UILabel *userEmailLabel;

@property (weak, nonatomic) IBOutlet UIView *emailUserProfilePictureView;
@property (weak, nonatomic) IBOutlet UIImageView *emailUserProfilePicture;


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
        
        self.emailUserProfilePictureView.hidden = YES;
        
        //fetch user info and location
        [self fetchAndVerifyUserInfoFromFBandAndUpdateUserLocationAndUpdateUI];
        
    }else {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"username"] && [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]) {
            [self.userEmailLabel setText:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"]];
            [self.userNameLabel setText:@"Email User"];
            
            //get user's location
            [self getUserLocationAndUpdateToServerWithFacebookID:nil];
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

#pragma mark - image pick/upload/display

- (IBAction)changeProfilePictureButtonTouchedHandler:(id)sender {
    QBImagePickerController *imagePickerController = [QBImagePickerController new];
    imagePickerController.delegate = self;
    imagePickerController.allowsMultipleSelection = YES;
    imagePickerController.maximumNumberOfSelection = 1;
    imagePickerController.mediaType = QBImagePickerMediaTypeImage;
    imagePickerController.prompt = @"Select your profile picture";
    imagePickerController.showsNumberOfSelectedAssets = YES;
    
    [self presentViewController:imagePickerController
                       animated:YES
                     completion:^{
                         NSLog(@"showing image picker controller");
                     }];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets {
    for (PHAsset *asset in assets) {
        // Do something with the asset
        //
        // get image metadata from phasset and set the UIImageView to be that photo.
        // and uploading the photo to S3 server, and update the returned URL to our own server.
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:PHImageManagerMaximumSize
                                                  contentMode:PHImageContentModeDefault
                                                      options:nil
                                                resultHandler:^(UIImage *result, NSDictionary *info) {
                                                    self.emailUserProfilePicture.image = result;
                                                    NSLog(@"finished setting up new profile picture");
                                                }];
    }
    [self dismissViewControllerAnimated:YES completion:NULL];
}

//  delegate methods for QBImagePickerController. Gets called when certain action occured.

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)qb_imagePickerController:(QBImagePickerController *)imagePickerController shouldSelectAsset:(PHAsset *)asset
{
    NSLog(@"should select: %@", [asset description]);
    return YES;
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAsset:(PHAsset *)asset
{
    NSLog([asset description]);
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didDeselectAsset:(PHAsset *)asset
{
    NSLog(@"deselect %@", [asset description]);
}




#pragma mark - location service

- (void)getUserLocationAndUpdateToServerWithFacebookID:(NSString*)facebook_id
{
    
    INTULocationManager *locMgr = [INTULocationManager sharedInstance];
    [locMgr requestLocationWithDesiredAccuracy:INTULocationAccuracyHouse
                                       timeout:10.0
                          delayUntilAuthorized:YES  // This parameter is optional, defaults to NO if omitted
                                         block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                                             if (status == INTULocationStatusSuccess) {
                                                 [self updateUserLatitude:[NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude]
                                                                Longitude:[NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude]
                                                           withFacebookID:facebook_id];
//                                                 [self updateUserLatitude:currentLocation.coordinate.latitude
//                                                                Longitude:currentLocation.coordinate.longitude
//                                                           withFacebookID:facebook_id];
                                             }
                                             else if (status == INTULocationStatusTimedOut) {
                                                 // Wasn't able to locate the user with the requested accuracy within the timeout interval.
                                                 // However, currentLocation contains the best location available (if any) as of right now,
                                                 // and achievedAccuracy has info on the accuracy/recency of the location in currentLocation.
                                                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                                 message:@"Time out: could not find your location"
                                                                                                delegate:nil
                                                                                       cancelButtonTitle:@"OK"
                                                                                       otherButtonTitles:nil];
                                                 [alert show];
                                                 
                                                 [self updateUserLatitude:[NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude]
                                                                Longitude:[NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude]
                                                           withFacebookID:facebook_id];
//                                                 [self updateUserLatitude:currentLocation.coordinate.latitude
//                                                                Longitude:currentLocation.coordinate.longitude
//                                                           withFacebookID:facebook_id];
                                             }
                                             else {
                                                 // An error occurred, more info is available by looking at the specific status returned.
                                                 NSLog(@"strange error while getting location, check status");
                                             }
                                         }];
}

- (void)updateUserLatitude:(NSString*)latitude Longitude:(NSString*)longitude withFacebookID:(NSString*)facebook_id
{
    NSString *updatePath = [NSString stringWithFormat:@"%@/user/update", serverURL];
    
    //if facebook user
    if ([FBSDKAccessToken currentAccessToken]) {
        NSLog(@"%@", longitude);
        NSLog(@"%@", latitude);
        
        NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:facebook_id, @"facebook_id", [[FBSDKAccessToken currentAccessToken] tokenString], @"auth_token", longitude, @"lng", latitude, @"lat", nil];
        NSLog([locationInfo description]);
        NSString *serverReply = [self sendRequestToURL:updatePath
                      withData:locationInfo
                    withMethod:@"PUT"];
        NSLog(@"facebook user update location reply: %@",serverReply);
    }else {
        //if email user
        NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"], @"username", [[NSUserDefaults standardUserDefaults] objectForKey:@"password"], @"password", longitude, @"lng", latitude, @"lat", nil];
        NSLog([locationInfo description]);
        NSString *serverReply = [self sendRequestToURL:updatePath
                      withData:locationInfo
                    withMethod:@"PUT"];
        NSLog(@"Email user update location reply: %@", serverReply);
    }
}

#pragma mark - user log out

/**
 Log out button for user logged in with email
 @param sender
        the log out button view
*/
- (IBAction)normalUserLogoutButtonHandler:(id)sender {
    
    if ([FBSDKAccessToken currentAccessToken]) {
        FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
        
        NSLog(@"facebook user log out");
        
        [login logOut];
    }else {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"username"] && [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]) {
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"username"];
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"password"];
            
            NSLog(@"email user log out");
            
            [self performSegueWithIdentifier:@"pop up login view" sender:self];
        }
    }
}


#pragma mark - notification handler

/**
 The handler for FBSDKAccessTokenChangeNotification
 */
- (void) observedAccessTokenChangeHandler
{
    if (![FBSDKAccessToken currentAccessToken]) {
        [self performSegueWithIdentifier:@"pop up login view" sender:self];
        [self.userNameLabel setText:@"Guest"];
        [self.userEmailLabel setText:@"Unknown"];
    }else {
        [self displayUserProfile];
        
        self.emailUserProfilePictureView.hidden = YES;
        
        [self fetchAndVerifyUserInfoFromFBandAndUpdateUserLocationAndUpdateUI];
    }
}

/**
 The handler for FBSDKProfileChangeNotification
 */
- (void) observedProfileChangeHandler
{
    if ([FBSDKProfile currentProfile]) {
        [self displayUserProfile];
    }
    
}

/**
 The handler for @"EmailUserIdChangeNotification". Send HTTP request to server, and "GET" user information from server
 @param emailUserIdChangeNotification
        contains the user_id sent from LoginViewController
 */
- (void)observedEmailUserIdChangeHandler:(NSNotification*)emailUserIdChangeNotificiation
{
    NSDictionary *emailUserId = [emailUserIdChangeNotificiation userInfo];
    NSString* getUserInfoServerReply = [self sendRequestToURL:[NSString stringWithFormat:@"%@/user/%@", serverURL, emailUserId[@"success"]]
                  withData:nil
                withMethod:@"GET"];
    NSLog(getUserInfoServerReply);
    
    NSDictionary* emailUserInfoDictionary = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[getUserInfoServerReply dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    
    if (emailUserInfoDictionary[@"error"] == nil) {
        
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

/**
 When user logged in with facebook, display user's name based on his/her facebook profile name
 */
- (void) displayUserProfile
{
    NSString *name = [NSString stringWithFormat:@"Name: %@", [FBSDKProfile currentProfile].name];
    self.userNameLabel.text = name;
}

/**
 Update user's profile info on UI, if the user has a facebook token then update it's email to the email of his facebook. If the user logged in with email, then display email as user's user name
 @param userInfo
        A NSDictionary contains user's email address(either from facebook, or registered email)
 */
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

/**
 Verify if Facebook user has been created in server based on their facebook_id  and auth_token, and if user existed on the server, it does nothing, otherwise create a new user on the server based on facebook_id and auth_token
 @param facebookID
        User's facebook_id
 */
- (void) isFacebookUserExistsOnServer:(NSString*)facebookID
{
    if ([FBSDKAccessToken currentAccessToken]) {
        NSDictionary* fbUserInfo = [[NSDictionary alloc] initWithObjectsAndKeys:facebookID,@"facebook_id",[[FBSDKAccessToken currentAccessToken] tokenString], @"auth_token", nil];
        NSString *verifyFacebookUserServerReply = [self sendRequestToURL:[self appendEncodedDictionary:fbUserInfo ToURL:[NSString stringWithFormat:@"%@/user/verify?", serverURL]]
                                                                withData:nil
                                                              withMethod:@"GET"];
        NSLog(@"facebook user existed on server?: %@", verifyFacebookUserServerReply);
    }
}


/**
 Async fetch user's information (id, email, gender, location, etc) from Facebook by calling Facebook's Graph API, update UI, and create user in server based on input.
 @param should
        if YES, the create user in server
        if NO, user with this facebook id has already existed in server
 */
- (void) fetchAndVerifyUserInfoFromFBandAndUpdateUserLocationAndUpdateUI
{
    if ([FBSDKAccessToken currentAccessToken]) {
        FBSDKGraphRequest *graphRequest = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:nil];
        [graphRequest startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (!error) {
                NSLog(@"%@",result);
                NSString *facebookID = [NSString stringWithFormat:@"%@", result[@"id"]];
                
                [self isFacebookUserExistsOnServer:facebookID];
                
                //update location
                [self getUserLocationAndUpdateToServerWithFacebookID:facebookID];
                
                [self performSelectorOnMainThread:@selector(updateUIwithUserInfo:) withObject:result waitUntilDone:NO];
            }
        }];
    }
}


//duplicated code from LoginViewController (description can also be found there)
#pragma mark - Server Query & JSON Parsing

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
//        NSLog(@"status code: %@", [response statusCode]);
        NSLog(@"error: %@", [error description]);
        return nil;
    }
    return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
}

/**
 parse server reply from JSON format to NSDictionary
 @param serverReply
        the reply in JSON format sent back from server
 @return key-value pair of JSON data in NSDictionary
 */
- (NSDictionary*)serverJsonReplyParser:(NSString*)serverReply
{
    return (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[serverReply dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}





@end
