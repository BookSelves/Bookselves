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

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet FBSDKLoginButton *facebookLoginButton;
@property (weak, nonatomic) IBOutlet UIButton *normalUserLogoutButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedAccessTokenChangeHandler)
                                                 name:FBSDKAccessTokenDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observedProfileChangeHandler) name:FBSDKProfileDidChangeNotification
                                               object:nil];
    
    if ([FBSDKAccessToken currentAccessToken]) {
        [self.userNameLabel setText:[NSString stringWithFormat:@"Name: %@", [FBSDKProfile currentProfile].name]];
        //hide normal log out button
    }else {
        //hider fb log out button
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewDidAppear:(BOOL)animated
{
    if ([FBSDKAccessToken currentAccessToken]) {
        //do something
    }else {
        [self performSegueWithIdentifier:@"pop up login view" sender:self];
    }
}

- (void) observedAccessTokenChangeHandler
{
    if (![FBSDKAccessToken currentAccessToken]) {
        [self performSegueWithIdentifier:@"pop up login view" sender:self];
    }else {
        [self displayUserProfile];
    }
}

- (void) observedProfileChangeHandler
{
    [self displayUserProfile];
}

- (void) displayUserProfile
{
    if ([FBSDKProfile currentProfile]) {
        NSString *name = [NSString stringWithFormat:@"Name: %@", [FBSDKProfile currentProfile].name];
        self.userNameLabel.text = name;
    }
}


@end
