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
#import "Utils.h"
#import "CoreLocation/CoreLocation.h"
#import <INTULocationManager/INTULocationManager.h>
#import <QBImagePickerController/QBImagePickerController.h>
#import <AFAmazonS3Manager/AFAmazonS3Manager.h>
#import <AWSS3/AWSS3.h>
#import <AWSCore/AWSCore.h>
#import <AWSCognito/AWSCognito.h>


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *normalUserLogoutButton;
@property (weak, nonatomic) IBOutlet UILabel *userEmailLabel;

@property (weak, nonatomic) IBOutlet UIView *emailUserProfilePictureView;
@property (weak, nonatomic) IBOutlet UIImageView *emailUserProfilePicture;

@end

@implementation ViewController

#pragma mark - some constants

static const int profile_image_size = 200;


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
            
            //download user image from s3 and set it to profile picture
            
            // ???: should brute force user's profile picture name or should retrieve the url from server
            
            [self downloadImage:[NSString stringWithFormat:@"%@-profile-picture.png", [[NSUserDefaults standardUserDefaults] objectForKey:@"user_id"]]
                     FromBucket:s3BucketName
         AndSetToImageView:self.emailUserProfilePicture];
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

#pragma mark - image pick/update to server/uplaod to s3

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
                                                    NSLog(@"finished setting up new profile picture");
                                                    UIImage *resizedImage = [self imageWithImage:result
                                                                                    scaledToSize:CGSizeMake(profile_image_size, profile_image_size)];
                                                    
                                                    [self createLoadingView];
                                                    [self uploadImage:resizedImage ToS3Bucket:s3BucketName andSetToImageView:self.emailUserProfilePicture];
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


//-------------------- image uplaod to s3 (referred from https://github.com/barrettbreshears/s3-objectiveC) ----------------

- (void) uploadImage:(UIImage*)image ToS3Bucket:(NSString*)bucket andSetToImageView:(UIImageView*)imageView
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-profile-picture.png",[[NSUserDefaults standardUserDefaults] objectForKey:@"username"]]];
    NSData *imageData = UIImagePNGRepresentation(image);
    [imageData writeToFile:path atomically:YES];
    
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    
    _uploadRequest = [AWSS3TransferManagerUploadRequest new];
    _uploadRequest.bucket = bucket;
    
    _uploadRequest.ACL = AWSS3ObjectCannedACLPublicRead;
    
    _uploadRequest.key = [NSString stringWithFormat:@"%@-profile-picture.png",[[NSUserDefaults standardUserDefaults] objectForKey:@"user_id"]];
    _uploadRequest.contentType = @"image/png";
    _uploadRequest.body = url;
    
    
    __weak ViewController *weakSelf = self;
    
    _uploadRequest.uploadProgress = ^(int64_t byteSent, int64_t totalByteSent, int64_t totalByteExpectedToSend) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.amountUploaded = totalByteSent;
            weakSelf.fileSize = totalByteExpectedToSend;
            [weakSelf updateUploadingUI];
        });
    };
    
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    
    [[transferManager upload:_uploadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        // once the uploadmanager finishes check if there were any errors
        if (task.error) {
            if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                switch (task.error.code) {
                    case AWSS3TransferManagerErrorCancelled:
                    case AWSS3TransferManagerErrorPaused:
                        break;
                        
                    default:
                        NSLog(@"Error: %@", task.error);
                        break;
                }
            } else {
                // Unknown error.
                NSLog(@"Error: %@", task.error);
            }
        }else{
            
            NSString *imageURLinS3 = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@", bucket, [NSString stringWithFormat:@"%@-profile-picture.png",[[NSUserDefaults standardUserDefaults] objectForKey:@"user_id"]]];
            
            NSLog(@"Success: %@", imageURLinS3);
            
            [self setImageFromFilePath:path toImageView:imageView]; //if upload successfully, set as profile picture
            
            NSDictionary *userInfoWithProfilePictureURL = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"], @"username", [[NSUserDefaults standardUserDefaults] objectForKey:@"password"], @"password", imageURLinS3, @"profile_url", nil];
            
            [Utils updateUserInfo:userInfoWithProfilePictureURL];
            
            [UIView animateWithDuration:0.3
                             animations:^{
                                 _loadingBg.alpha = 0;
                                 _progressView.alpha = 0;
                                 _progressLabel.alpha = 0;
                             } completion:^(BOOL finished) {
                                 _loadingBg.hidden = 0;
                             }];
        }
        return nil;
    }];
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void) updateUploadingUI
{
     _progressLabel.text = [NSString stringWithFormat:@"Uploading:%.0f%%", ((float)self.amountUploaded/ (float)self.fileSize) * 100];
}

- (void) createLoadingView
{
    _loadingBg = [[UIView alloc] initWithFrame:self.view.frame];
    [_loadingBg setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.35]];
    [self.view addSubview:_loadingBg];
    
    _progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 50)];
    _progressView.center = self.view.center;
    [_progressView setBackgroundColor:[UIColor whiteColor]];
    [_loadingBg addSubview:_progressView];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 50)];
    [_progressLabel setTextAlignment:NSTextAlignmentCenter];
    [_progressView addSubview:_progressLabel];
    
    _progressLabel.text = @"Uploading:";
}

#pragma mark - download image from s3 and set to profile picture

- (void) downloadImage:(NSString*)image FromBucket:(NSString*)bucket AndSetToImageView:(UIImageView*)imageView
{
    //start animating downloading indicator
    [self createDownloadingIndicator];
    
    NSString *downloadingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-profile-picture.png",[[NSUserDefaults standardUserDefaults] objectForKey:@"user_id"]]];
    
    NSURL *downloadingURL = [NSURL fileURLWithPath:downloadingPath];
    
    _downloadRequest = [AWSS3TransferManagerDownloadRequest new];
    
    _downloadRequest.bucket = bucket;
    _downloadRequest.key = image;
    _downloadRequest.downloadingFileURL = downloadingURL;
    
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    
    [[transferManager download:_downloadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                            withBlock:^id(BFTask *task) {
                                                                //stop animation of indicator
                                                                [_activityIndicator stopAnimating];
                                                                
                                                                if (task.error){
                                                                    if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                                                                        switch (task.error.code) {
                                                                            case AWSS3TransferManagerErrorCancelled:
                                                                            case AWSS3TransferManagerErrorPaused:
                                                                                break;
                                                                            default:
                                                                                NSLog(@"Error: %@", task.error);
                                                                                break;
                                                                        }
                                                                    } else {
                                                                        // Unknown error.
                                                                        NSLog(@"Error: %@", task.error);
                                                                    }
                                                                }
                                                                if (task.result) {
                                                                    AWSS3TransferManagerDownloadOutput *downloadOutput = task.result;
                                                                    
                                                                    //File downloaded successfully.
                                                                    [self setImageFromFilePath:downloadingPath
                                                                                   toImageView:imageView];
                                                                }
                                                                return nil;
                                                            }];
}

- (void) setImageFromFilePath:(NSString*)filePath toImageView:(UIImageView*)imageView
{
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];
    if (!image) {
        return;
    }else {
        imageView.image = image;
    }
}

- (void)createDownloadingIndicator
{
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.center = self.view.center;
    _activityIndicator.hidesWhenStopped = YES;
    
    [self.view addSubview:_activityIndicator];
    
    [_activityIndicator startAnimating];
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
                                                 NSString *latitude = [NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude];
                                                 NSString *longitude = [NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude];
                                                 
                                                 if ([FBSDKAccessToken currentAccessToken]) {
                                                     NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%@",facebook_id], @"facebook_id", [[FBSDKAccessToken currentAccessToken] tokenString], @"auth_token", longitude, @"lng", latitude, @"lat", nil];
                                                     
                                                     [Utils updateUserInfo:locationInfo];
                                                 }else {
                                                     NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"], @"username", [NSString stringWithFormat:@"%@", [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]], @"password", longitude, @"lng", latitude, @"lat", nil];
                                                     
                                                     [Utils updateUserInfo:locationInfo];
                                                 }
                                            }else if (status == INTULocationStatusTimedOut) {
                                                 // Wasn't able to locate the user with the requested accuracy within the timeout interval.
                                                 // However, currentLocation contains the best location available (if any) as of right now,
                                                 // and achievedAccuracy has info on the accuracy/recency of the location in currentLocation.
                                                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                                                 message:@"Time out: could not find your location"
                                                                                                delegate:nil
                                                                                       cancelButtonTitle:@"OK"
                                                                                       otherButtonTitles:nil];
                                                [alert show];
                                                NSString *latitude = [NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude];
                                                NSString *longitude = [NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude];
                                            
                                                
                                                if ([FBSDKAccessToken currentAccessToken]) {
                                                    NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithFormat:@"%@",facebook_id], @"facebook_id", [[FBSDKAccessToken currentAccessToken] tokenString], @"auth_token", longitude, @"lng", latitude, @"lat", nil];
                                                    [Utils updateUserInfo:locationInfo];
                                                }else {
                                                    NSDictionary *locationInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"], @"username", [NSString stringWithFormat:@"%@", [[NSUserDefaults standardUserDefaults] objectForKey:@"password"]], @"password", longitude, @"lng", latitude, @"lat", nil];
                         
                                                    [Utils updateUserInfo:locationInfo];
                                                }
                                             }
                                             else {
                                                 // An error occurred, more info is available by looking at the specific status returned.
                                                 NSLog(@"strange error while getting location, status: %ld", (long)status);
                                                 
                                             }
                                         }];
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
            [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"user_id"];
            
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
    NSString* getUserInfoServerReply = [Utils sendRequestToURL:[NSString stringWithFormat:@"%@/user/%@", serverURL, emailUserId[@"success"]]
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
        NSString *verifyFacebookUserServerReply = [Utils sendRequestToURL:[Utils appendEncodedDictionary:fbUserInfo ToURL:[NSString stringWithFormat:@"%@/user/verify?", serverURL]]
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




@end
