//
//  LoginViewController.m
//  Bookselves-App
//
//  Created by Junyu Wang on 4/28/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import "LoginViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "constants.h"
#import "ViewController.h"

@interface LoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *inputEmail;
@property (weak, nonatomic) IBOutlet UITextField *inputPassword;
@property (weak, nonatomic) IBOutlet UIButton *registerButton;
@property (weak, nonatomic) IBOutlet UIButton *goToSignInViewButton;

@property (weak, nonatomic) IBOutlet UIView *loginView;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;
@property (weak, nonatomic) IBOutlet UITextField *inputEmail_signIn;
@property (weak, nonatomic) IBOutlet UITextField *inputPassword_signIn;

@end

@implementation LoginViewController

#pragma mark - view life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pushToProfileView)
                                                 name: FBSDKAccessTokenDidChangeNotification
                                               object:nil];
    
    self.inputEmail.hidden = YES;
    self.inputPassword.hidden = YES;
    self.registerButton.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/**
 dismiss current view controller and go to profile view
 */
- (void) pushToProfileView
{
    if ([FBSDKAccessToken currentAccessToken]) {
        [self dismissViewControllerAnimated:YES completion:^{
            NSLog(@"user log in");
        }];
    }
}

#pragma mark - user log in

/**
 Called when user clicked "Sign In" button, and then the user will go to the sign in view
 @param sender
        "Sign In" button
 **/
- (IBAction)goToSignInViewButtonHandler:(id)sender {
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.inputEmail.alpha = 0;
                         self.inputPassword.alpha = 0;
                         self.registerButton.alpha = 0;

                         self.loginView.alpha = 1;
                     }
                     completion:^(BOOL finished) {
                         self.loginView.hidden = !finished;
                     }];
}

/**
 called when user click the Sign In button.
 @param sender
        Sign In button
 */
- (IBAction)signInButtonHandler:(id)sender {
    if ([self.inputEmail_signIn.text isEqualToString:@""] || [self.inputPassword_signIn.text isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Email or Password can't be empty"
                                                        message:@"You must enter both email and password to log in"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }else {
        NSLog(@"verifying user information");
        
        NSDictionary *signInInputData = [[NSDictionary alloc] initWithObjectsAndKeys:self.inputEmail_signIn.text, @"username", self.inputPassword_signIn.text, @"password", nil];
        //NSLog([self appendEncodedDictionary:signInInputData ToURL:[NSString stringWithFormat:@"%@/user/verify?", serverURL]]);
        NSString* verifyUserServerReply = [self sendRequestToURL:[self appendEncodedDictionary:signInInputData ToURL:[NSString stringWithFormat:@"%@/user/verify?", serverURL]]
                      
                                                        withData:nil
                    
                                                      withMethod:@"GET"];
        NSLog(verifyUserServerReply);
        
        NSDictionary *verifyUserServerReplyDictionary = [self serverJsonReplyParser:verifyUserServerReply];
        
        //if user exists go back to the profile view controller.
        if (verifyUserServerReplyDictionary[@"success"] != nil) {
            
            //store user information into NSUserDefault
            [[NSUserDefaults standardUserDefaults] setObject:signInInputData[@"username"] forKey:@"username"];
            [[NSUserDefaults standardUserDefaults] setObject:signInInputData[@"password"] forKey:@"password"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"EmailUserIdChangeNotification" object:nil userInfo:verifyUserServerReplyDictionary];
            
            [self dismissViewControllerAnimated:YES
                                     completion:^{
                                         NSLog(@"User log in via Email");
                                     }];
        }else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:verifyUserServerReplyDictionary[@"error"]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

#pragma mark - user registration
/**
 handler for the "Sign Up" button, it hides the current sign in view and displays the sign up view
 @param sender
        "Sign Up" button
 */
- (IBAction)signUpButtonHandler:(id)sender {
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.inputEmail.alpha = 1;
                         self.inputPassword.alpha = 1;
                         self.registerButton.alpha = 1;
                         self.loginView.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         self.loginView.hidden = finished;
                     }];
    
    self.inputEmail.hidden = NO;
    self.inputPassword.hidden = NO;
    self.registerButton.hidden = NO;
}

/**
 Handler for register button
 @param sender
        the "Submit" button
 */
- (IBAction)registerButtonHandler:(id)sender {
    if ([self.inputEmail.text isEqualToString:@""] || [self.inputPassword.text isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Email or Password can't be empty"
                                                        message:@"You must enter both email and password to register an account"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }else {
        NSLog(@"sending data to the server");
        
        NSDictionary *registrationData = [[NSDictionary alloc] initWithObjectsAndKeys:self.inputEmail.text, @"username", self.inputPassword.text, @"password", nil];
        
        NSString *registerUserServerReply = [self sendRequestToURL:[NSString stringWithFormat:@"%@/user/create", serverURL]
                      
                                                  withData:registrationData
                          
                                                withMethod:@"POST"];
        NSLog(registerUserServerReply);
        
        NSDictionary *registerUserServerReplyDictionary = [self serverJsonReplyParser:registerUserServerReply];
        
        //if registered successfully, log user in and dismiss current view controller
        if (registerUserServerReplyDictionary[@"success"] != nil) {
            
            //store user information into NSUserDefault
            [[NSUserDefaults standardUserDefaults] setObject:registrationData[@"username"] forKey:@"username"];
            [[NSUserDefaults standardUserDefaults] setObject:registrationData[@"password"] forKey:@"password"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"EmailUserIdChangeNotification" object:nil userInfo:registerUserServerReplyDictionary];
            
            [self dismissViewControllerAnimated:YES
                                     completion:^{
                                         NSLog(@"user finished registration and logs in");
                                     }];
        }else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:registerUserServerReplyDictionary[@"error"]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

#pragma mark - formatize URL

/**
 Append information in dictonary to URL, used for user verification
 @param dictionary
        A NSDictionary that contains needed info to append to URL
 @param url
        The original URL
 @code
 signInInputData --> [@"username":@"user_name", @"password":@"user_password"]
 [self appendEncodedDictionary:signInInputData ToURL:@"http://example.com/user/verify?"] --> @"http://example.com/user/verify?username=user_name&password=user_password"
 @endcode
 */
- (NSString*) appendEncodedDictionary:(NSDictionary*)dictionary ToURL:(NSString*)url
{
    return [url stringByAppendingString:[NSString stringWithFormat:@"%@", [self turnDictionaryIntoParamsOfURL:dictionary]]];
}

/**
 Turn information in dictionary to parameters of URL
 @param dictionary
        The NSDictionary containing query information
 @code
 dictionary --> [@"username":@"user_name", @"password":@"user_password"]
 NSString* output = [self turnDictionaryIntoParamsOfURL:dictionary]
 output --> @"username=user_name&password=user_password"
 @endcode
 */
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

/**
 encode dictionary into NSData
 @param dictionary
        NSDictionary
 */
- (NSData*)encodeDictionary:(NSDictionary*)dictionary
{
    NSString *encodedDictionary = [self turnDictionaryIntoParamsOfURL:dictionary];
    //NSLog(encodedDictionary);
    return [encodedDictionary dataUsingEncoding:NSUTF8StringEncoding];
}

/**
 send HTTP request
 @param url
        endpoint of server
 @param data
        data in the body of HTTP request
 @param method
        "GET", "POST", "PATCH", "DELETE"
 */
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
        NSLog(@"%@", [error description]);
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



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
