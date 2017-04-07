//
//  MCLThemeManager.m
//  mclient
//
//  Copyright © 2014 - 2017 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

#import "MCLThemeManager.h"

@import CoreLocation;
@import WebKit;

#import "EDSunriseSet.h"

#import "MCLSettings.h"
#import "MCLTheme.h"
#import "MCLDefaultTheme.h"
#import "MCLNightTheme.h"
#import "MCLLoadingView.h"
#import "MCLErrorView.h"
#import "MCLReadSymbolView.h"
#import "MCLBadgeView.h"


NSString * const MCLThemeChangedNotification = @"ThemeChangedNotification";

@interface MCLThemeManager()

@property (strong, nonatomic) MCLSettings *settings;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSDateComponents *sunrise;
@property (strong, nonatomic) NSDateComponents *sunset;

@end

@implementation MCLThemeManager

#pragma mark - Initializers

- (instancetype)initWithSettings:(MCLSettings *)settings
{
    self = [super init];
    if (!self) return nil;

    self.settings = settings;
    [self initiliazeLocationManager];
    [self updateSun];
    
    return self;
}

#pragma mark - Sunset

- (void)initiliazeLocationManager
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
}

- (BOOL)isAfterSunset:(NSDateComponents*)dateComponents
{
    if (dateComponents.hour > self.sunset.hour) {
        return YES;
    }

    if (dateComponents.hour == self.sunset.hour &&
        dateComponents.minute > self.sunset.minute
    ) {
        return YES;
    }

    if (dateComponents.hour == self.sunset.hour &&
        dateComponents.minute == self.sunset.minute &&
        dateComponents.second >= self.sunset.second
    ) {
        return YES;
    }

    return NO;
}

- (BOOL)isBeforeSunrise:(NSDateComponents*)dateComponents
{
    if (dateComponents.hour < self.sunrise.hour) {
        return YES;
    }

    if (dateComponents.hour == self.sunrise.hour &&
        dateComponents.minute < self.sunrise.minute
    ) {
        return YES;
    }

    if (dateComponents.hour == self.sunrise.hour &&
        dateComponents.minute == self.sunrise.minute &&
        dateComponents.second <= self.sunrise.second
    ) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Public

- (void)updateSun
{
    if (![self.settings isSettingActivated:MCLSettingNightModeAutomatically]) {
        return;
    }

    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        self.sunrise = [[NSDateComponents alloc] init];
        self.sunrise.hour = 8;
        self.sunrise.minute = 0;
        self.sunrise.second = 0;

        self.sunset = [[NSDateComponents alloc] init];
        self.sunset.hour = 20;
        self.sunset.minute = 0;
        self.sunset.second = 0;
    }
    else {
        [self.locationManager startUpdatingLocation];
        [self.locationManager requestWhenInUseAuthorization];

        double latitude = self.locationManager.location.coordinate.latitude;
        double longitude = self.locationManager.location.coordinate.longitude;
        EDSunriseSet *sunriseSet = [EDSunriseSet sunrisesetWithDate:[NSDate date]
                                                           timezone:[NSTimeZone localTimeZone]
                                                           latitude:latitude
                                                          longitude:longitude];
        self.sunrise = sunriseSet.localSunrise;
        self.sunset = sunriseSet.localSunset;

        [self.locationManager stopUpdatingLocation];
    }
}

- (void)loadTheme
{
    if ([self.settings isSettingActivated:MCLSettingNightModeAutomatically]) {
        [self loadThemeBasedOnTime];
    }
    else {
        [self loadThemeBasedOnSettings];
    }
}

- (void)loadThemeBasedOnSettings
{
    id <MCLTheme> theme;
    if ([self.settings isSettingActivated:MCLSettingNightModeEnabled]) {
        theme = [[MCLNightTheme alloc] init];
    } else {
        theme = [[MCLDefaultTheme alloc] init];
    }

    [self applyTheme:theme];
}

- (void)loadThemeBasedOnTime
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *now = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
                                        fromDate:[NSDate date]];
    id <MCLTheme> theme;
    if ([self isAfterSunset:now] || [self isBeforeSunrise:now]) {
        theme = [[MCLNightTheme alloc] init];
    } else {
        theme = [[MCLDefaultTheme alloc] init];
    }
    [self applyTheme:theme];
}

- (void)applyTheme: (id <MCLTheme>)theme
{
    if (self.currentTheme && [self.currentTheme identifier] == [theme identifier]) {
        return;
    }

    self.currentTheme = theme;

    UIBarStyle barStyle = [theme isDark] ? UIBarStyleBlack : UIBarStyleDefault;
    [[UINavigationBar appearance] setBarStyle:barStyle];

    [[UILabel appearance] setTextColor:[theme textColor]];

    [[UINavigationBar appearance] setBarTintColor:[theme navigationBarBackgroundColor]];
    [[UINavigationBar appearance] setTranslucent:YES];
    [[UINavigationBar appearance] setAlpha:0.7f];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: [theme navigationBarTextColor]}];

    [[UIToolbar appearance] setBarTintColor:[theme toolbarBackgroundColor]];
    [[UIToolbar appearance] setTintColor:[theme tintColor]];

    [[UITableView appearance] setBackgroundColor:[theme tableViewBackgroundColor]];
    [[UITableView appearance] setSeparatorColor:[theme tableViewSeparatorColor]];

    [[UIRefreshControl appearance] setBackgroundColor:[theme refreshControlBackgroundColor]];

    [[UISearchBar appearance] setBackgroundImage:[[UIImage alloc] init]];
    [[UISearchBar appearance] setBackgroundColor:[theme searchBarBackgroundColor]];

//    [[UITableViewCell appearance] setBackgroundColor:[theme tableViewCellBackgroundColor]];
//    NSArray<Class <UIAppearanceContainer>> *classes = @[NSClassFromString(@"MCLBoardListTableViewController"), NSClassFromString(@"MCLThreadListTableViewController")];
////                                                        NSClassFromString(@"MCLMessageListViewController"),
////                                                        NSClassFromString(@"MCLProfileTableViewController")];
//    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:classes] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLBoardListTableViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLDetailViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLResponsesTableViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLSettingsViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLThreadListTableViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLMessageListViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];
    [[UITableViewCell appearanceWhenContainedInInstancesOfClasses:@[NSClassFromString(@"MCLProfileTableViewController")]] setBackgroundColor:[theme tableViewCellBackgroundColor]];

    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UITableViewCell class]]] setTextColor:[theme textColor]];

    [[MCLLoadingView appearance] setBackgroundColor:[theme backgroundColor]];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[MCLLoadingView class]]] setTextColor:[theme overlayTextColor]];

    [[MCLErrorView appearance] setBackgroundColor:[theme backgroundColor]];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[MCLErrorView class]]] setTextColor:[theme overlayTextColor]];

    [[MCLBadgeView appearance] setBackgroundColor:[theme badgeViewBackgroundColor]];

    [[MCLReadSymbolView appearance] setColor:[theme tintColor]];

    UIActivityIndicatorViewStyle indicatorViewStyle = [theme isDark] ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
    [[UIActivityIndicatorView appearance] setActivityIndicatorViewStyle:indicatorViewStyle];

    [[UITextView appearance] setBackgroundColor:[theme textViewBackgroundColor]];

    UIKeyboardAppearance keyboardAppearance = [theme isDark] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
    [[UITextField appearance] setKeyboardAppearance:keyboardAppearance];
    [[UITextField appearance] setTextColor:[theme textViewTextColor]];

    [[UIWebView appearance] setBackgroundColor:[theme webViewBackgroundColor]];
    [[WKWebView appearance] setBackgroundColor:[theme webViewBackgroundColor]];
    [[UIScrollView appearanceWhenContainedInInstancesOfClasses:@[[WKWebView class]]] setBackgroundColor:[theme webViewBackgroundColor]];

    [self.settings setInteger:[theme identifier] forSetting:MCLSettingTheme];

    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        for (UIView *view in window.subviews) {
            [view removeFromSuperview];
            [window addSubview:view];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:MCLThemeChangedNotification object:self];
}

@end
