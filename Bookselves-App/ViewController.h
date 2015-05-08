//
//  ViewController.h
//  Bookselves-App
//
//  Created by Junyu Wang on 4/28/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AWSS3/AWSS3.h>
#import <AWSCore/AWSCore.h>
#import <AWSCognito/AWSCognito.h>

@interface ViewController : UIViewController

@property (nonatomic) int user_id;

@property (nonatomic, strong) UIView *loadingBg;
@property (nonatomic, strong) UIView *progressView;
@property (nonatomic, strong) UILabel *progressLabel;

@property (strong, nonatomic) AWSS3TransferManagerUploadRequest *uploadRequest;
@property (strong, nonatomic) AWSS3TransferManagerDownloadRequest *downloadRequest;
@property (nonatomic) uint64_t fileSize;
@property (nonatomic) uint64_t amountUploaded;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

