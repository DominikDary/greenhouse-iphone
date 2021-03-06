//
//  ProfileControllerDelegate.h
//  Greenhouse
//
//  Created by Roy Clarkson on 9/16/10.
//  Copyright 2010 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@class Profile;


@protocol ProfileControllerDelegate<NSObject>

- (void)fetchProfileDidFinishWithResults:(Profile *)profile;
- (void)fetchProfileDidFailWithError:(NSError *)error;

@end

