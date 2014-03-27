//
//  DZLPageView.h
//  DZLPageView
//
//  Created by Sam Dods on 21/09/2013.
//  Copyright (c) 2013 Sam Dods. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DZLPageView;
@class DZLPageViewCell;

@protocol DZLPageViewDataSource <NSObject>
- (DZLPageViewCell *)pageView:(DZLPageView *)pageView cellForPageAtIndex:(NSUInteger)pageIndex;
- (NSUInteger)numberOfPagesInPageView:(DZLPageView *)pageView;
@optional
- (CGSize)pageView:(DZLPageView *)pageView sizeOfCellForPageAtIndex:(NSUInteger)pageIndex;
@end


@protocol DZLPageViewDelegate <UIScrollViewDelegate>
@optional
- (void)pageView:(DZLPageView *)pageView didTapCellForPageAtIndex:(NSUInteger)pageIndex;
- (void)pageView:(DZLPageView *)pageView didScrollToPageAtIndex:(NSUInteger)pageIndex viewOffset:(CGFloat)viewOffset;
@end


@interface DZLPageView : UIScrollView
@property (assign, nonatomic) NSUInteger currentInnerPageIndex;
@property (weak, nonatomic) id<DZLPageViewDataSource> dataSource;
@property (weak, nonatomic) id<DZLPageViewDelegate> delegate;
@property (assign, nonatomic) BOOL shouldLoopScroll;
@property (assign, nonatomic, readonly) NSUInteger numberOfPages;
- (void)scrollToPageAtIndex:(NSUInteger)viewIndex animated:(BOOL)animated;
- (DZLPageViewCell *)cellForPageAtIndex:(NSUInteger)pageIndex;
- (DZLPageViewCell *)mostVisibleCellForPageAtIndex:(NSUInteger)pageIndex;
- (void)enumerateVisibleCellsUsingBlock:(void(^)(id cell, NSInteger pageIndex, BOOL *stop))block;
- (void)reload;
- (NSUInteger)currentPageIndex;
@end
