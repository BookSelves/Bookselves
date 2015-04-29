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

- (void) pushToProfileView
{
    if ([FBSDKAccessToken currentAccessToken]) {
        [self dismissViewControllerAnimated:YES completion:^{
            NSLog(@"user log in");
        }];
    }
}

#pragma mark - user log in

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


#pragma mark - user registration
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
        
        NSString *serverReplyData = [self sendRequestToURL:[NSString stringWithFormat:@"%@/user/create", serverURL]
                      withData:registrationData
                          withMethod:@"POST"];
        NSLog(serverReplyData);
        
    }
}

- (NSData*)encodeDictionary:(NSDictionary*)dictionary
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
        return nil;
    }
    return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
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
