//
//  TodayViewController.m
//  Hue Widget
//
//  Created by Yazid Azahari on 5/6/14.
//  Copyright (c) 2014 Yazid Azahari. All rights reserved.
//

#define HUE_API_USER    @"newdeveloper"

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

@interface TodayViewController () <NCWidgetProviding> {
    NSMutableArray *dataSource;
    NSString *ipAddress;
    
    NSURLSessionDataTask *ipAddressTask;
    NSURLSessionDataTask *lightsTask;
    
    NSMutableDictionary *lightStates;
}

@end

@implementation TodayViewController

- (void)viewDidLoad{
    [super viewDidLoad];

    ipAddress = @"";
    dataSource = [NSMutableArray array];
    lightStates = [NSMutableDictionary dictionary];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:nil
                                                          delegate:self
                                                     delegateQueue:nil];
    
    NSString *getApiPath = @"http://www.meethue.com/api/nupnp";
    NSString *getUrlString = getApiPath;

    ipAddressTask = [session dataTaskWithURL:[NSURL URLWithString:getUrlString] completionHandler:nil];
    
    [ipAddressTask resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    NSLog(@"dataTask didReceiveResponse: %@", response);
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{

    if(dataTask == ipAddressTask){
        NSError *JSONError = nil;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&JSONError];
        if (JSONError)
        {
            NSLog(@"Serialization error: %@", JSONError.localizedDescription);
        } else {
            NSLog(@"ipAddressTask Data: %@", json);
            
            NSDictionary *dictionary = [json firstObject];
            
            ipAddress = [NSString stringWithString:[dictionary objectForKey:@"internalipaddress"]];
            
            NSURLSession *session = [NSURLSession sessionWithConfiguration:nil
                                                                  delegate:self
                                                             delegateQueue:nil];
            
            NSString *apiPath = [NSString stringWithFormat:@"/api/%@/lights/",HUE_API_USER];
            NSString *urlString = [NSString stringWithFormat:@"http://%@%@",ipAddress,apiPath];
            NSLog(@"Light Task URL: %@", urlString);
            
            lightsTask = [session dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:nil];

            [lightsTask resume];
        }
    } else if(dataTask == lightsTask){
        NSError *JSONError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&JSONError];
        if (JSONError)
        {
            NSLog(@"Serialization error: %@", JSONError.localizedDescription);
        } else {
            NSLog(@"lightsTask Data: %@", json);
            
            for(NSString* key in json){
                NSString *lightName = [[json objectForKey:key] objectForKey:@"name"];
                [dataSource addObject:lightName];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                [self updateLightStates];
            });
        }
    }
    
}

-(void)updateLightStates
{
    NSURLSession *session = [NSURLSession sharedSession];

    for(int i=0;i<[dataSource count];i++){
        
        NSString *apiPath = [NSString stringWithFormat:@"/api/%@/lights/%i",HUE_API_USER,i+1];
        NSString *urlString = [NSString stringWithFormat:@"http://%@%@",ipAddress,apiPath];
        NSURLSessionDataTask *getTask = [session dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSLog(@"%@", json);
            NSDictionary *lightState = [json objectForKey:@"state"];
            
            NSNumber *currentState = [lightState objectForKey:@"on"];
            [lightStates setObject:currentState forKey:[NSString stringWithFormat:@"%i",i+1]];
            NSLog(@"On state for Light %i: %@",i+1,[lightState objectForKey:@"on"]);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
            });
        }];
        [getTask resume];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encoutered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

#pragma UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [dataSource count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [dataSource objectAtIndex:indexPath.row];
    
    NSNumber *currentState = (NSNumber *)[lightStates objectForKey:[NSString stringWithFormat:@"%i",indexPath.row+1]];
    
    if([currentState boolValue]){
        cell.textLabel.textColor = [UIColor whiteColor];
    } else {
        cell.textLabel.textColor = [UIColor lightGrayColor];
    }
    
    return cell;
}

#pragma UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSString *apiPath = [NSString stringWithFormat:@"/api/%@/lights/%i/state", HUE_API_USER, indexPath.row+1];
    NSString *urlString = [NSString stringWithFormat:@"http://%@%@",ipAddress,apiPath];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"PUT"];
    
    NSNumber *currentState = (NSNumber *)[lightStates objectForKey:[NSString stringWithFormat:@"%i",indexPath.row+1]];
    NSNumber *newState = [NSNumber numberWithBool:[currentState boolValue]?NO:YES];

    NSDictionary *mapData = @{@"on":newState};
    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:mapData options:0 error:&error];
    [request setHTTPBody:postData];
    
    NSURLSessionDataTask *postTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"PUT Result: %@", json);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [lightStates setObject:newState forKey:[NSString stringWithFormat:@"%i",indexPath.row+1]];
            [self.tableView reloadData];
        });
    }];
    
    [postTask resume];
}


@end
