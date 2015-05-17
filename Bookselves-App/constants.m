//
//  constants.m
//  Bookselves-App
//
//  Created by Junyu Wang on 4/28/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import "constants.h"

@implementation constants

NSString* const serverURL = @"http://bookselves.herokuapp.com";
NSString* const createUserURL =@"http://bookselves.herokuapp.com/user/create";
NSString* const verifyUserURL =@"http://bookselves.herokuapp.com/user/verify";
NSString* const updateUserURL =@"http://bookselves.herokuapp.com/user/update";
NSString* const getUserURLwithoutID =@"http://bookselves.herokuapp.com/user/";

NSString* const s3BucketName = @"bookselves-user-profile-pictures";


@end
