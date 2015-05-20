//
//  SignUpAndLogInViewController.m
//  Bookselves-App
//
//  Created by Junyu Wang on 5/2/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import "SignUpAndLogInViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "LoginViewController.h"

@interface SignUpAndLogInViewController ()

@property (weak, nonatomic) IBOutlet UIButton *facebookSignUpButton;
@property (weak, nonatomic) IBOutlet UIButton *emailSignUpButton;

@end

@implementation SignUpAndLogInViewController

#pragma mark - view life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self drawRoundButton:self.facebookSignUpButton];
    [self drawRoundButton:self.emailSignUpButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    LoginViewController *vc = [segue destinationViewController];\
    if ([[segue identifier] isEqualToString:@"push to sign up view"]) {
        NSLog(@"hello");
        vc.viewType = @"sign up";
    }else {
        vc.viewType = @"sign in";
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

#pragma mark - draw button UI

- (void) drawRoundButton:(UIButton*)button
{
    button.layer.cornerRadius = button.bounds.size.width/2.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = (__bridge CGColorRef)(button.titleLabel.textColor);
}

#pragma mark - facebook login

- (IBAction)facebookSignUpButtonTouchedHandler:(id)sender {
    
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
    [login logInWithReadPermissions:@[@"email"] handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            NSLog(@"error: %@",error);
        } else if (result.isCancelled) {
            NSLog(@"Cancelled");
        } else {
            if ([result.grantedPermissions containsObject:@"email"]) {
                // Do work
                [self dismissViewControllerAnimated:YES completion:^{
                    NSLog(@"user logged in through facebook");
                }];
            }
        }
    }];
}

@end
