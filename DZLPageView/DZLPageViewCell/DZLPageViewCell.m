//
//  DZLPageViewCell.m
//  SDMultiViewDemo
//
//  Created by Sam Dods on 22/09/2013.
//  Copyright (c) 2013 Sam Dods. All rights reserved.
//

#import "DZLPageViewCell.h"

@interface DZLPageViewCell ()
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@end

@implementation DZLPageViewCell

#pragma mark - setup

- (id)init
{
    self = [super init];
    [self setupGestureRecognizer];
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    [self setupGestureRecognizer];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self setupGestureRecognizer];
    return self;
}

- (void)setupGestureRecognizer
{
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapCell:)];
    [self addGestureRecognizer:self.tapGestureRecognizer];
}


#pragma mark - actions

- (void)didTapCell:(UITapGestureRecognizer *)tapGestureRecognizer
{
    if (self.tapHandlerBlock != NULL) {
        self.tapHandlerBlock();
    }
}

@end
