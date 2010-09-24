//
//  EventController.m
//  Greenhouse
//
//  Created by Roy Clarkson on 8/31/10.
//  Copyright 2010 VMware, Inc. All rights reserved.
//

#import "EventController.h"
#import "OAuthManager.h"
#import "Event.h"


@implementation EventController

@synthesize delegate = _delegate;


#pragma mark -
#pragma mark Instance methods

- (void)fetchEvents
{
	NSURL *url = [[NSURL alloc] initWithString:EVENTS_URL];
	
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:url 
																   consumer:[OAuthManager sharedInstance].consumer
																	  token:[OAuthManager sharedInstance].accessToken
																	  realm:OAUTH_REALM
														  signatureProvider:nil]; // use the default method, HMAC-SHA1
	
	[url release];
	
	[request setHTTPMethod:@"GET"];
	[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
	
	DLog(@"%@", request);
	
	[self cancelDataFetcherRequest];
	
	_dataFetcher = [[OAAsynchronousDataFetcher alloc] initWithRequest:request
															 delegate:self
													didFinishSelector:@selector(fetchEvents:didFinishWithData:)
													  didFailSelector:@selector(fetchEvents:didFailWithError:)];
	
	[_dataFetcher start];
	
	[request release];
}

- (void)fetchEvents:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data
{
	[_dataFetcher release];
	_dataFetcher = nil;
	
	NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	DLog(@"%@", responseBody);
	
	NSMutableArray *events = [[[NSMutableArray alloc] init] autorelease];
	
	if (ticket.didSucceed)
	{
		NSArray *jsonArray = [responseBody yajl_JSON];
		
		DLog(@"%@", jsonArray);
		
		for (NSDictionary *d in jsonArray)
		{
			Event *event = [[Event alloc] initWithDictionary:d];
			[events addObject:event];
			[event release];
		}
	}
	else 
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
														message:@"A problem occurred while retrieving the event data." 
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
	
	[responseBody release];
	
	[_delegate fetchEventsDidFinishWithResults:events];
}

- (void)fetchEvents:(OAServiceTicket *)ticket didFailWithError:(NSError *)error
{
	[self request:ticket didFailWithError:error didFailDelegate:_delegate didFailSelector:@selector(fetchEventsDidFailWithError:)];
}


#pragma mark -
#pragma mark NSObject methods

- (void)dealloc
{
	[super dealloc];
}

@end
