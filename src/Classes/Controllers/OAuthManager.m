//
//  OAuthManager.m
//  Greenhouse
//
//  Created by Roy Clarkson on 6/7/10.
//  Copyright 2010 VMware, Inc. All rights reserved.
//

#import "OAuthManager.h"

#define OAUTH_TOKEN					@"oauth_token"
#define OAUTH_TOKEN_SECRET			@"oauth_token_secret"
#define OAUTH_CALLBACK				@"oauth_callback"
#define OAUTH_VERIFIER				@"oauth_verifier"
#define KEYCHAIN_SERVICE_PROVIDER	@"Greenhouse"


static OAuthManager *sharedInstance = nil;
static OAToken *sharedAccessToken = nil;
static OAConsumer *sharedConsumer = nil;

@implementation OAuthManager

@dynamic authorized;
@dynamic accessToken;
@synthesize activityAlertView = _activityAlertView;


#pragma mark -
#pragma mark Static methods

// This class is configured to function as a singleton. 
// Use this class method to obtain the shared instance of the class.
+ (OAuthManager *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
		{
			sharedInstance = [[OAuthManager alloc] init];
		}
    }
	
    return sharedInstance;
}


#pragma mark -
#pragma mark Instance methods

- (OAToken *)accessToken
{
	if (sharedAccessToken == nil)
	{
		sharedAccessToken = [[OAToken alloc] initWithKeychainUsingAppName:@"Greenhouse" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
	}
	
	return sharedAccessToken;
}

- (OAConsumer *)consumer
{
	if (sharedConsumer == nil)
	{
		sharedConsumer = [[OAConsumer alloc] initWithKey:OAUTH_CONSUMER_KEY secret:OAUTH_CONSUMER_SECRET];
	}
	
	return sharedConsumer;
}

- (BOOL)isAuthorized
{
	return (self.accessToken != nil);
}

- (void)removeAccessToken
{
	[self.accessToken removeFromDefaultKeychainWithAppName:@"Greenhouse" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
	sharedAccessToken = nil;
}

- (void)cancelDataFetcherRequest
{
	if (_dataFetcher)
	{
		DLog(@"");
		
		[_dataFetcher cancel];
		[_dataFetcher release];
		_dataFetcher = nil;
	}
}

- (void)fetchUnauthorizedRequestToken;
{
	self.activityAlertView = [[ActivityAlertView alloc] initWithActivityMessage:@"Authorizing Greenhouse app..."];
	[_activityAlertView startAnimating];
	
	OAConsumer *consumer = [[OAConsumer alloc] initWithKey:OAUTH_CONSUMER_KEY
													secret:OAUTH_CONSUMER_SECRET];
	
    NSURL *url = [NSURL URLWithString:OAUTH_REQUEST_TOKEN_URL];
	
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:url 
																   consumer:consumer 
																	  token:nil   // we don't have a Token yet
																	  realm:OAUTH_REALM
														  signatureProvider:nil]; // use the default method, HMAC-SHA1
	
	[consumer release];
	
	[request setHTTPMethod:@"POST"];
	[request setOAuthParameterName:OAUTH_CALLBACK withValue:OAUTH_CALLBACK_URL];
	
	DLog(@"%@", request);
	
	[self cancelDataFetcherRequest];
	
	_dataFetcher = [[OAAsynchronousDataFetcher alloc] initWithRequest:request
															 delegate:self
													didFinishSelector:@selector(requestTokenTicket:didFinishWithData:)
													  didFailSelector:@selector(requestTokenTicket:didFailWithError:)];
	
	[_dataFetcher start];
	
	[request release];
}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	[_dataFetcher release];
	_dataFetcher = nil;
	
	[_activityAlertView stopAnimating];
	self.activityAlertView = nil;
	
	NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	DLog(@"%@", responseBody);
	
	if (ticket.didSucceed) 
	{
		OAToken *requestToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];
		[requestToken storeInDefaultKeychainWithAppName:@"GreenhouseRequestToken" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
		[self authorizeRequestToken:requestToken];
		[requestToken release];
	}
	else
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil 
															message:@"A problem occurred while authorizing the app. Please check the availability at greenhouse.springsource.org." 
														   delegate:nil 
												  cancelButtonTitle:@"OK" 
												  otherButtonTitles:nil];
		[alertView show];
		[alertView release];
	}
	
	[responseBody release];
}

- (void)requestTokenTicket:(OAServiceTicket *)ticket didFailWithError:(NSError *)error
{
	[_dataFetcher release];
	_dataFetcher = nil;
	
	[_activityAlertView stopAnimating];
	self.activityAlertView = nil;
	
	DLog(@"%@", [error localizedDescription]);
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil 
														message:@"A problem occurred while authorizing the app. Please check the availability at greenhouse.springsource.org." 
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

- (void)authorizeRequestToken:(OAToken *)requestToken;
{
	[requestToken retain];
	NSString *urlString = [NSString stringWithFormat:@"%@?%@=%@", OAUTH_AUTHORIZE_URL, OAUTH_TOKEN, requestToken.key];
	[requestToken release];
	
	DLog(@"%@", urlString);
	NSURL *url = [NSURL URLWithString:urlString];
	[[UIApplication sharedApplication] openURL:url];
}

- (void)processOauthResponse:(NSURL *)url delegate:(id)aDelegate didFinishSelector:(SEL)finishSelector didFailSelector:(SEL)failSelector
{
	delegate = aDelegate;
	didFinishSelector = finishSelector;
	didFailSelector = failSelector;
	
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
	
	NSArray *pairs = [[url query] componentsSeparatedByString:@"&"];
	
	for (NSString *pair in pairs) 
	{
		NSRange firstEqual = [pair rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
		
		if (firstEqual.location == NSNotFound) 
		{
			continue;
		}
		
		NSString *key = [pair substringToIndex:firstEqual.location];
		NSString *value = [pair substringFromIndex:firstEqual.location+1];
		
		[result setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
				   forKey:[key stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	
	[self fetchAccessToken:(NSString *)[result objectForKey:OAUTH_VERIFIER]];
}

- (void)fetchAccessToken:(NSString *)oauthVerifier
{
	self.activityAlertView = [[ActivityAlertView alloc] initWithActivityMessage:nil];
	[_activityAlertView startAnimating];
	
	OAConsumer *consumer = [[OAConsumer alloc] initWithKey:OAUTH_CONSUMER_KEY
													secret:OAUTH_CONSUMER_SECRET];
		
	OAToken *requestToken = [[OAToken alloc] initWithKeychainUsingAppName:@"GreenhouseRequestToken" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
	
    NSURL *url = [NSURL URLWithString:OAUTH_ACCESS_TOKEN_URL];
	
    OAMutableURLRequest *request = [[OAMutableURLRequest alloc] initWithURL:url 
																   consumer:consumer 
																	  token:requestToken
																	  realm:OAUTH_REALM
														  signatureProvider:nil]; // use the default method, HMAC-SHA1
	
	[consumer release];
	[requestToken removeFromDefaultKeychainWithAppName:@"GreenhouseRequestToken" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
	[requestToken release];
	
	[request setHTTPMethod:@"POST"];
	[request setOAuthParameterName:OAUTH_VERIFIER withValue:oauthVerifier];
	
	[self cancelDataFetcherRequest];
	
	_dataFetcher = [[OAAsynchronousDataFetcher alloc] initWithRequest:request
															 delegate:self
													didFinishSelector:@selector(accessTokenTicket:didFinishWithData:)
													  didFailSelector:@selector(accessTokenTicket:didFailWithError:)];
	
	[_dataFetcher start];
	
	[request release];
}

- (void)accessTokenTicket:(OAServiceTicket *)ticket didFinishWithData:(NSData *)data 
{
	[_dataFetcher release];
	_dataFetcher = nil;
	
	[_activityAlertView stopAnimating];
	self.activityAlertView = nil;
	
	NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	DLog(@"%@", responseBody);
	
	if (ticket.didSucceed)
	{
		OAToken *accessToken = [[OAToken alloc] initWithHTTPResponseBody:responseBody];		
		[accessToken storeInDefaultKeychainWithAppName:@"Greenhouse" serviceProviderName:KEYCHAIN_SERVICE_PROVIDER];
		[accessToken release];		
	}
	else
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil 
															message:@"A problem occurred while authorizing the app. Please check the availability at greenhouse.springsource.org." 
														   delegate:nil 
												  cancelButtonTitle:@"OK" 
												  otherButtonTitles:nil];
		[alertView show];
		[alertView release];
	}
	
	[responseBody release];
	
	if ([delegate respondsToSelector:didFinishSelector])
	{
		[delegate performSelector:didFinishSelector];
	}	
}

- (void)accessTokenTicket:(OAServiceTicket *)ticket didFailWithError:(NSError *)error
{
	[_dataFetcher release];
	_dataFetcher = nil;
	
	DLog(@"%@", [error localizedDescription]);
	
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil 
														message:@"A problem occurred while authorizing the app. Please check the availability at greenhouse.springsource.org." 
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
	
	if ([delegate respondsToSelector:didFailSelector])
	{
		[delegate performSelector:didFailSelector];
	}	
}


#pragma mark -
#pragma mark NSObject methods

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
	
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}

@end
