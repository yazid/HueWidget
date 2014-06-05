//
//  TodayViewController.h
//  Hue Widget
//
//  Created by Yazid Azahari on 5/6/14.
//  Copyright (c) 2014 Yazid Azahari. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TodayViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, NSURLSessionDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
