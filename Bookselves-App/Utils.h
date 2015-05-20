//
//  Utils.h
//  Bookselves-App
//
//  Created by Junyu Wang on 5/4/15.
//  Copyright (c) 2015 Bookselves. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject

+ (NSString*) appendEncodedDictionary:(NSDictionary*)dictionary ToURL:(NSString*)url;

+ (NSString *) turnDictionaryIntoParamsOfURL:(NSDictionary*)dictionary;

+ (NSData*)encodeDictionary:(NSDictionary*)dictionary;

+ (NSString *)sendRequestToURL:(NSString *)url withData:(NSDictionary *)data withMethod: (NSString *)method;

+ (NSDictionary*)serverJsonReplyParser:(NSString*)serverReply;

+ (void)updateUserInfo:(NSDictionary*)userInfo;

@end
