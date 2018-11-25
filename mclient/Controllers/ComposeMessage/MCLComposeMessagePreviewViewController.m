//
//  MCLPreviewMessageViewController.m
//  mclient
//
//  Copyright © 2014 - 2018 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

#import "MCLComposeMessagePreviewViewController.h"

#import "Reachability.h"
#import "UIViewController+Additions.h"
#import "MCLDependencyBag.h"
#import "MCLHTTPClient.h"
#import "MCLSettings.h"
#import "MCLPreviewMessageRequest.h"
#import "MCLSendMessageRequest.h"
#import "MCLTheme.h"
#import "MCLThemeManager.h"
#import "MCLLoadingView.h"
#import "MCLMServiceErrorView.h"
#import "MCLInternetConnectionErrorView.h"
#import "MCLMultilineTitleLabel.h"
#import "MCLMessageListViewController.h"
#import "MCLMessage.h"
#import "MCLThread.h"

@interface MCLComposeMessagePreviewViewController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) UIBarButtonItem *sendButton;
@property (strong, nonatomic) NSString *previewText;

@end

@implementation MCLComposeMessagePreviewViewController

#pragma mark - UIViewController life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    id <MCLTheme> currentTheme = self.bag.themeManager.currentTheme;
    self.view.backgroundColor = [currentTheme backgroundColor];
}

#pragma mark - MCLLoadingContentViewControllerDelegate

- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController configureNavigationItem:(UINavigationItem *)navigationItem
{
    navigationItem.title = self.message.subject;
    self.sendButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Send", nil)
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(sendButtonPressed:)];
    self.sendButton.enabled = NO;
    navigationItem.rightBarButtonItem = self.sendButton;
}

- (NSString *)loadingViewControllerRequestsTitleString:(MCLLoadingViewController *)loadingViewController
{
    return self.message.subject;
}

- (UILabel *)loadingViewControllerRequestsTitleLabel:(MCLLoadingViewController *)loadingViewController
{
    return [self titleLabel];
}

- (UILabel *)titleLabel
{
    return [[MCLMultilineTitleLabel alloc] initWithThemeManager:self.bag.themeManager andTitle:self.message.subject];
}

- (void)loadingViewControllerStartsRefreshing:(MCLLoadingViewController *)loadingViewController
{ }

- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController hasRefreshedWithData:(NSArray *)newData forKey:(NSNumber *)key
{
    NSArray *data = [newData copy];

    self.sendButton.enabled = YES;

    NSString *messageTextKey = @"";
    switch ([self.bag.settings integerForSetting:MCLSettingShowImages]) {
        case kMCLSettingsShowImagesWifi: {
            Reachability *wifiReach = [Reachability reachabilityForLocalWiFi];
            messageTextKey = [wifiReach currentReachabilityStatus] == ReachableViaWiFi
                ? @"previewTextHtmlWithImages"
                : @"previewTextHtml";
            break;
        }
        case kMCLSettingsShowImagesNever:
            messageTextKey = @"previewTextHtml";
            break;

        case kMCLSettingsShowImagesAlways:
        default:
            messageTextKey = @"previewTextHtmlWithImages";
            break;
    }

    MCLMessage *previewMessage = [[MCLMessage alloc] init];
    previewMessage.textHtml = [NSString stringWithFormat:@"<div id=\"content\">%@</div>", [[data firstObject] objectForKey:messageTextKey]];
    previewMessage.textHtmlWithImages = previewMessage.textHtml;
    self.previewText = [previewMessage messageHtmlWithTopMargin:20
                                                          width:self.view.bounds.size.width
                                                          theme:[self.bag.themeManager currentTheme]
                                                       settings:self.bag.settings];
    [self.webView loadHTMLString:self.previewText baseURL:nil];
}

#pragma mark - Actions

- (void)sendButtonPressed:(id)sender
{
    self.sendButton.enabled = NO;

    MCLSendMessageRequest *sendRequest = [[MCLSendMessageRequest alloc] initWithClient:self.bag.httpClient message:self.message];
    [sendRequest loadWithCompletionHandler:^(NSError *error, NSArray *data) {
        if (error) {
            [self presentError:error withCompletion:^{
                self.sendButton.enabled = YES;
            }];
            return;
        }

        [self dismissViewControllerAnimated:YES completion:^{
            [self.delegate message:self.message sentWithType:self.message.type];
        }];
    }];
}

@end
