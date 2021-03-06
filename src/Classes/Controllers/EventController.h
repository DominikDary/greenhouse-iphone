//
//  EventController.h
//  Greenhouse
//
//  Created by Roy Clarkson on 8/31/10.
//  Copyright 2010 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OAuthController.h"
#import "EventControllerDelegate.h"


@interface EventController : OAuthController 
{ 
	id<EventControllerDelegate> _delegate;
}

@property (nonatomic, assign) id<EventControllerDelegate> delegate;

- (void)fetchEvents;
- (void)fetchEvents:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data;
- (void)fetchEvents:(OAServiceTicket *)ticket didFailWithError:(NSError *)error;

@end
