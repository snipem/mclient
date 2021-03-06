//
//  MCLDetailViewController.m
//  mclient
//
//  Created by Christopher Reitz on 19.09.14.
//  Copyright (c) 2014 Christopher Reitz. All rights reserved.
//

#import "MCLMessageListViewController.h"

#import "utils.h"
#import "MCLThread.h"
#import "MCLBoard.h"

@implementation MCLMessageListViewController

@synthesize splitViewButton = _splitViewButton;

+ (NSString *)messageHtmlSkeletonForHtml:(NSString *)html withTopMargin:(int)topMargin
{
    return [NSString stringWithFormat:@""
            "<html>"
            "<head>"
            "<script type=\"text/javascript\">"
            "    function spoiler(obj) {"
            "        if (obj.nextSibling.style.display === 'none') {"
            "            obj.nextSibling.style.display = 'inline';"
            "        } else {"
            "            obj.nextSibling.style.display = 'none';"
            "        }"
            "    }"
            "</script>"
            "<style>"
            "    * {"
            "        font-family: \"Helvetica Neue\";"
            "        font-size: 14px;"
            "        -webkit-text-size-adjust: none;"
            "    }"
            "    body {"
            "        margin: %ipx 20px 10px 20px;"
            "        padding: 0px;"
            "    }"
            "    a {"
            "        word-break: break-all;"
            "    }"
            "    img {"
            "        max-width: 100%%;"
            "    }"
            "    button > img {"
            "        content:url(\"http://www.maniac-forum.de/forum/images/spoiler.png\");"
            "        width: 17px;"
            "    }"
            "</style>"
            "</head>"
            "<body>%@</body>"
            "</html>", topMargin, html];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark - Abstract

- (void)loadThread:(MCLThread *)inThread fromBoard:(MCLBoard *)inBoard
{
    mustOverride();
}


#pragma mark - SplitViewButtonHandler

-(void) turnSplitViewButtonOn: (UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *) popoverController
{
    NSString *activeDetailViewControllerClassName = NSStringFromClass([[[[self.splitViewController.viewControllers lastObject] viewControllers] firstObject] class]);

    NSString *barButtonTitle = NSLocalizedString(@"Threads", nil);
    if ([activeDetailViewControllerClassName isEqualToString:@"MCLMessageListViewController"]) {
        barButtonTitle = NSLocalizedString(@"Boards", nil);
    }
    barButtonItem.title = barButtonTitle;
    _splitViewButton = barButtonItem;

    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

-(void)turnSplitViewButtonOff {
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    _splitViewButton = nil;
    self.masterPopoverController = nil;
    
}

-(void) setSplitViewButton:(UIBarButtonItem *)splitViewButton forPopoverController:(UIPopoverController *)popoverController {
    if (splitViewButton != _splitViewButton) {
        if (splitViewButton) {
            [self turnSplitViewButtonOn:splitViewButton forPopoverController:popoverController];
        } else {
            [self turnSplitViewButtonOff];
        }
    }
}

@end
