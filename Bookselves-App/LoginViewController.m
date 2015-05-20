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
#import "Utils.h"

@interface LoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *inputEmail;
@property (weak, nonatomic) IBOutlet UITextField *inputPassword;
@property (weak, nonatomic) IBOutlet UIButton *registerButton;
@property (weak, nonatomic) IBOutlet UIButton *goToSignInViewButton;
@property (weak, nonatomic) IBOutlet UILabel *goToSignInViewLabel;

@property (weak, nonatomic) IBOutlet UIView *loginView;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;
@property (weak, nonatomic) IBOutlet UITextField *inputEmail_signIn;
@property (weak, nonatomic) IBOutlet UITextField *inputPassword_signIn;
@property (weak, nonatomic) IBOutlet UIButton *goToSignUpViewButton;
@property (weak, nonatomic) IBOutlet UILabel *goToSignUpViewLabel;

@property (weak, nonatomic) IBOutlet UIButton *backButton;

@end

@implementation LoginViewController

#pragma mark - view life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self displayCorrectView];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)backButtonTouchedHandler:(id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 NSLog(@"Back to sign up view controller");
                             }];
}

- (void)displayCorrectView
{
    if ([self.viewType isEqualToString:@"sign up"]) {
        NSLog(@"what");
        [self hideLogInView];
    }else if ([self.viewType isEqualToString:@"sign in"]) {
        [self hideSignUpView];
    }
}

- (void)hideLogInView
{
    self.loginView.hidden = YES;
}

- (void)hideSignUpView
{
    self.inputEmail.hidden = YES;
    self.inputPassword.hidden = YES;
    self.registerButton.hidden = YES;
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
                         
                         self.goToSignUpViewLabel.alpha = 1;
                         self.goToSignUpViewButton.alpha = 1;
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
        NSString* verifyUserServerReply = [Utils sendRequestToURL:[Utils appendEncodedDictionary:signInInputData ToURL:[NSString stringWithFormat:@"%@/user/verify?", serverURL]]
                      
                                                        withData:nil
                    
                                                      withMethod:@"GET"];
        NSLog(verifyUserServerReply);
        
        NSDictionary *verifyUserServerReplyDictionary = [Utils serverJsonReplyParser:verifyUserServerReply];
        
        //if user exists go back to the profile view controller.
        if (verifyUserServerReplyDictionary[@"success"] != nil) {
            
            //store user information into NSUserDefault
            [[NSUserDefaults standardUserDefaults] setObject:signInInputData[@"username"] forKey:@"username"];
            [[NSUserDefaults standardUserDefaults] setObject:signInInputData[@"password"] forKey:@"password"];
            [[NSUserDefaults standardUserDefaults] setObject:verifyUserServerReplyDictionary[@"success"] forKey:@"user_id"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"EmailUserIdChangeNotification" object:nil userInfo:verifyUserServerReplyDictionary];
            
            [self performSegueWithIdentifier:@"push to profile view" sender:self];
            
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
                         self.goToSignInViewLabel.alpha = 1;
                         self.goToSignInViewButton.alpha = 1;
                         
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
        
        NSString *registerUserServerReply = [Utils sendRequestToURL:[NSString stringWithFormat:@"%@/user/create", serverURL]
                      
                                                  withData:registrationData
                          
                                                withMethod:@"POST"];
        NSLog(registerUserServerReply);
        
        NSDictionary *registerUserServerReplyDictionary = [Utils serverJsonReplyParser:registerUserServerReply];
        
        //if registered successfully, log user in and dismiss current view controller
        if (registerUserServerReplyDictionary[@"success"] != nil) {
            
            //store user information into NSUserDefault
            [[NSUserDefaults standardUserDefaults] setObject:registrationData[@"username"] forKey:@"username"];
            [[NSUserDefaults standardUserDefaults] setObject:registrationData[@"password"] forKey:@"password"];
            [[NSUserDefaults standardUserDefaults] setObject:registerUserServerReplyDictionary[@"success"] forKey:@"user_id"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"EmailUserIdChangeNotification" object:nil userInfo:registerUserServerReplyDictionary];
            
            [self performSegueWithIdentifier:@"push to profile view" sender:self];
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


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
