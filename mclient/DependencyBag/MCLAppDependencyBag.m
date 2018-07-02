//
//  MCLAppDependencyBag.m
//  mclient
//
//  Copyright © 2014 - 2018 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

@import HockeySDK;

#import "MCLAppDependencyBag.h"

#import "ImgurSession.h"

#import "MCLAppRouterDelegate.h"
#import "MCLFeatures.h"
#import "MCLSettings.h"
#import "MCLRouter.h"
#import "MCLLogin.h"
#import "MCLThemeManager.h"
#import "MCLFoundationHTTPClient.h"
#import "MCLNotificationManager.h"
#import "MCLLaunchViewController.h"
#import "MCLBoardListTableViewController.h"

@interface MCLAppDependencyBag () <IMGSessionDelegate>

@end

@implementation MCLAppDependencyBag

@synthesize features;
@synthesize login;
@synthesize httpClient;
@synthesize router;
@synthesize settings;
@synthesize notificationManager;
@synthesize themeManager;

#pragma mark - Initializer

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;

    [self configure];

    return self;
}

#pragma mark - Configuration

- (void)configure
{
    self.features = [[MCLFeatures alloc] initWithStage:kFeatureStage];

    [self configureCrashReporter];
    self.login = [[MCLLogin alloc] initWithBag:self];
    self.httpClient = [[MCLFoundationHTTPClient alloc] initWithLogin:self.login];
    self.router = [[MCLRouter alloc] initWithBag:self];
    self.router.delegate = [[MCLAppRouterDelegate alloc] initWithBag:self];
    self.settings = [[MCLSettings alloc] initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    self.notificationManager = [[MCLNotificationManager alloc] initWithBag:self];
    self.themeManager = [[MCLThemeManager alloc] initWithSettings:self.settings];

    [self.themeManager loadTheme];

    [IMGSession anonymousSessionWithClientID:kImgurID withDelegate:self];
}

- (void)configureCrashReporter
{
    if (![self.features isFeatureWithNameEnabled:MCLFeatureCrashReporter]) {
        return;
    }

    BITHockeyManager *hockeyManager = [BITHockeyManager sharedHockeyManager];
    [hockeyManager configureWithIdentifier:[NSString stringWithFormat:@"%@", HOCKEYAPP_ID]];
    [hockeyManager.crashManager setCrashManagerStatus:BITCrashManagerStatusAlwaysAsk];
    [hockeyManager startManager];
    [hockeyManager.authenticator authenticateInstallation];
    [hockeyManager.updateManager checkForUpdate];
}

#pragma mark - Public

- (void)launchRootWindow:(void (^)(UIWindow *window))windowHandler
{
    UIWindow *rootWindow = [self.router makeRootWindow];
    MCLBoardListTableViewController *boardsListVC = (MCLBoardListTableViewController *)self.router.masterViewController.childViewControllers.firstObject;

    UIWindow *launchWindow = [self.router makeLaunchWindow];
    windowHandler(launchWindow);

    [self.login testLoginWithCompletionHandler:^(NSError *error, BOOL success) {
        [boardsListVC updateVerifyLoginViewWithSuccess:success];

        [self.router replaceRootWindow:rootWindow];
        windowHandler(rootWindow);
    }];
}

@end
