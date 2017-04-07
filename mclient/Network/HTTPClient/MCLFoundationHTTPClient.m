//
//  MCLFoundationHTTPClient.m
//  mclient
//
//  Copyright © 2014 - 2017 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

#import "MCLFoundationHTTPClient.h"

#import "Reachability.h"
#import "MCLLogin.h"

@interface MCLFoundationHTTPClient ()

@property (strong, nonatomic) MCLLogin *login;

@end

@implementation MCLFoundationHTTPClient

- (instancetype)initWithLogin:(MCLLogin *)login
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.login = login;

    return self;
}

#pragma mark - Request Helpers

- (void)getRequestToUrlString:(NSString *)urlString
                   needsLogin:(BOOL)needsLogin
            completionHandler:(void (^)(NSError *error, NSDictionary *json))completion
{
    [self requestWithHTTPMethod:@"GET"
                    toUrlString:urlString
                       withVars:nil
                           body:nil
                     needsLogin:needsLogin
              completionHandler:completion];
}

- (void)postRequestToUrlString:(NSString *)urlString
                      withVars:(NSDictionary *)vars
                    needsLogin:(BOOL)needsLogin
             completionHandler:(void (^)(NSError *error, NSDictionary *json))completion
{
    [self requestWithHTTPMethod:@"POST"
                    toUrlString:urlString
                       withVars:vars body:nil
                     needsLogin:needsLogin
              completionHandler:completion];
}

- (void)putRequestToUrlString:(NSString *)urlString
                     withVars:(NSDictionary *)vars
                   needsLogin:(BOOL)needsLogin
            completionHandler:(void (^)(NSError *error, NSDictionary *json))completion
{
    [self requestWithHTTPMethod:@"PUT"
                    toUrlString:urlString
                       withVars:vars body:nil
                     needsLogin:needsLogin
              completionHandler:completion];
}

- (void)deleteRequestToUrlString:(NSString *)urlString
                        withVars:(NSDictionary *)vars
                      needsLogin:(BOOL)needsLogin
               completionHandler:(void (^)(NSError *error, NSDictionary *json))completion
{
    [self requestWithHTTPMethod:@"DELETE"
                    toUrlString:urlString
                       withVars:vars
                           body:nil
                     needsLogin:needsLogin
              completionHandler:completion];
}

- (void)requestWithHTTPMethod:(NSString *)httpMethod
                  toUrlString:(NSString *)urlString
                     withVars:(NSDictionary *)vars
                         body:(NSData *)body
                   needsLogin:(BOOL)needsLogin
            completionHandler:(void (^)(NSError *error, NSDictionary *json))completion
{
    if ([self noInternetConnection]) {
        [self completeWithNoInternetConnectionError:completion];
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = httpMethod;
    [request setValue:@"gzip" forHTTPHeaderField:@"accept-encoding"];

    if (needsLogin) {
        NSDictionary *loginData = [self.login loginData];
        if (loginData) {
            NSString *authValue = [self authValueFromLoginData:loginData];
            [request setValue:authValue forHTTPHeaderField:@"Authorization"];
        }
    }

    if (body) {
        request.HTTPBody = body;
    }
    else if (vars) {
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString *requestFields = @"";
        for (id key in vars) {
            requestFields = [requestFields stringByAppendingFormat:@"%@=%@&", key, [self percentEscapeString:[vars objectForKey:key]]];
        }
        request.HTTPBody = [requestFields dataUsingEncoding:NSUTF8StringEncoding];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    });

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *responseError) {
        NSDictionary *reply = nil;
        NSNumber *errorCode = nil;
        NSString *errorMessage = nil;

        if (responseError) {
            switch ([responseError code]) {
                case -1012:
                    errorCode = @(401);
                    break;

                default:
                    errorCode = @(-1);
                    break;
            }
        }
        else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&jsonError];

            switch (statusCode) {
                case 200:
                    reply = json;
                    break;

                case 404:
                    errorCode = @(404);
                    errorMessage = [NSString stringWithFormat:NSLocalizedString([errorCode stringValue], nil), [json objectForKey:@"error"]];
                    break;

                case 502:
                    errorCode = @(-1);
                    errorMessage = [NSString stringWithFormat:NSLocalizedString([errorCode stringValue], nil), [json objectForKey:@"error"]];
                    break;

                default:
                    errorCode = @(statusCode);
                    break;
            }
        }

        NSError *errorPtr;
        if (errorCode) {
            errorPtr = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier]
                                           code:[errorCode integerValue]
                                       userInfo:@{NSLocalizedDescriptionKey:errorMessage ?: NSLocalizedString([errorCode stringValue], nil)}];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            completion(errorPtr, reply);
        });
    }] resume];
}

#pragma mark - Private Helpers

- (void)completeWithLoginError:(void (^)(NSError *, NSDictionary *))completion
{
    NSNumber *errorCode = @(404);
    NSError *errorPtr = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier]
                                            code:[errorCode integerValue]
                                        userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString([errorCode stringValue], nil)}];
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(errorPtr, nil);
    });
}

- (void)completeWithNoInternetConnectionError:(void (^)(NSError *, NSDictionary *))completion
{
    NSNumber *errorCode = @-2;
    NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier]
                                         code:[errorCode integerValue]
                                     userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString([errorCode stringValue], nil)}];
    completion(error, nil);
}

- (BOOL)noInternetConnection
{
    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];

    return networkStatus == NotReachable;
}

- (NSString *)authValueFromLoginData:(NSDictionary *)loginData
{
    NSString *username = [loginData objectForKey:@"username"];
    NSString *password = [loginData objectForKey:@"password"];
    NSString *authString = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:0]];

    return authValue;
}

- (NSString *)percentEscapeString:(NSString *)string
{
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}

@end
