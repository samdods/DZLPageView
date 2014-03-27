//
//  DZLPageViewCell.h
//  SDMultiViewDemo
//
//  Created by Sam Dods on 22/09/2013.
//  Copyright (c) 2013 Sam Dods. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DZLPageViewCell : UIView

@property (copy, nonatomic) void(^tapHandlerBlock)(void);

@end
