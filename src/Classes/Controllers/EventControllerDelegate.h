//
//  EventControllerDelegate.h
//  Greenhouse
//
//  Created by Roy Clarkson on 9/16/10.
//  Copyright 2010 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol EventControllerDelegate<NSObject>

- (void)fetchEventsDidFinishWithResults:(NSArray *)events;
- (void)fetchEventsDidFailWithError:(NSError *)error;

@end
