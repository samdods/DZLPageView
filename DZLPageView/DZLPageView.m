//
//  DZLPageView.m
//  DZLPageView
//
//  Created by Sam Dods on 21/09/2013.
//  Copyright (c) 2013 Sam Dods. All rights reserved.
//

#import "DZLPageView.h"
#import "DZLPageViewCell.h"


//The following must both >= 1
static const NSInteger kNumberOfViewsToKeepInMemoryBeforeCurrent = 3;
static const NSInteger kNumberOfViewsToKeepInMemoryAfterCurrent = 3;
static const NSInteger kNumberOfLoopsIfInfinite = 200;


@interface DZLPageView ()
@property (assign, nonatomic) NSUInteger numberOfPages;
@property (strong, nonatomic) NSMutableArray *cachedCells;
// the following properties are for caching the horizontal offset and sizes of cells.
@property (strong, nonatomic) NSMutableArray *horizontalOffsetByPageIndex;
@property (strong, nonatomic) NSMutableArray *cellSizeByPageIndex;
// the following property means that we don't have to reload the cells each time layoutSubviews is called.
@property (assign, nonatomic) NSInteger previouslyLoadedCurrentPageIndex;
// the following properties are just used for some black magic during device rotation or if the view is auto-resized, etc.
@property (assign, nonatomic) CGSize previousBoundsSize;
@property (assign, nonatomic) CGFloat previousContentOffsetFraction;
@end



@implementation DZLPageView

#pragma mark - UIView overrides

- (void)layoutSubviews
{
  // need to perform some black magic here, in case the device is rotated or view is auto-resized for some reason,
  // we need to ensure the content offset is set correctly after the view has changed.
  CGSize boundsSize = self.bounds.size;
  if (boundsSize.width == 0) return;
  NSUInteger numberOfLoops = self.numberOfLoops;
  if (boundsSize.width != self.previousBoundsSize.width) {
    self.cellSizeByPageIndex = nil;
    self.horizontalOffsetByPageIndex = nil;
    self.previouslyLoadedCurrentPageIndex = -1;
    CGSize size = boundsSize;
    self.contentSize = CGSizeMake(self.numberOfPages * numberOfLoops * size.width, size.height);
    if (self.previousContentOffsetFraction > 0) {
      self.contentOffset = CGPointMake(self.previousContentOffsetFraction * self.contentSize.width, 0);
    }
  }

  if (self.shouldLoopScroll) {
    CGFloat diffX = 0;
    NSUInteger numberOfPages = self.numberOfPages;
    NSUInteger currentPageIndex = self.currentInnerPageIndex;
    CGFloat temp = numberOfPages * boundsSize.width * floorf(numberOfLoops / 2);
    if (currentPageIndex <= ceil((CGFloat)numberOfPages / 2)) {
      diffX = temp;
    } else if (currentPageIndex >= numberOfPages * floorf((CGFloat)numberOfLoops - 0.5)) {
      diffX = temp * -1;
    }
    if (diffX != 0) {
      diffX += self.contentOffset.x;
      self.contentOffset = CGPointMake(diffX, 0);
    }
  }

  if ([self.delegate respondsToSelector:@selector(pageView:didScrollToPageAtIndex:viewOffset:)]) {
    NSUInteger externalIndex = self.currentInnerPageIndex % self.numberOfPages;
    [self.delegate pageView:self didScrollToPageAtIndex:externalIndex viewOffset:self.scrollOffsetX];
  }
  [self loadVisibleViews];

  // keep a copy of the last known bounds size and the content offset as a fraction of the total content size.
  self.previousBoundsSize = self.bounds.size;
  self.previousContentOffsetFraction = self.contentSize.width == 0 ? 0 : self.contentOffset.x / self.contentSize.width;
}



#pragma mark - properties

- (NSUInteger)currentInnerPageIndex
{
  CGFloat viewWidth = CGRectGetWidth(self.bounds);
  NSInteger viewIndex = viewWidth == 0 ? 0 : (NSUInteger)floor((self.contentOffset.x * 2.0f + viewWidth) / (viewWidth * 2.0f));
  NSUInteger numberOfViews = self.numberOfPages * self.numberOfLoops;
  return viewIndex < 0 ? 0 : (viewIndex >= (NSInteger)numberOfViews) ? numberOfViews - 1 : (NSUInteger)viewIndex;
}

- (NSUInteger)currentPageIndex
{
  return self.currentInnerPageIndex % self.numberOfPages;
}

- (void)setCurrentInnerPageIndex:(NSUInteger)currentInnerPageIndex
{
  [self scrollToPageAtIndex:currentInnerPageIndex animated:NO];
}

- (NSMutableArray *)cachedCells
{
  // if _cachedCells is nil, then reload in case dataSource has been set since last reload.
  return _cachedCells ?: ([self reload], _cachedCells);
}

- (NSUInteger)numberOfPages
{
  return _numberOfPages ?: (_numberOfPages = [self.dataSource numberOfPagesInPageView:self]);
}


#pragma mark - public interface

- (void)scrollToPageAtIndex:(NSUInteger)viewIndex animated:(BOOL)animated
{
  [self cachedCells]; // force reload if necessary
  CGRect viewBounds = self.bounds;
  CGFloat offsetX = viewIndex * CGRectGetWidth(viewBounds);
  [self scrollRectToVisible:CGRectMake(offsetX, 0, CGRectGetWidth(viewBounds), CGRectGetHeight(viewBounds)) animated:animated];
  [self loadVisibleViews];
}

- (DZLPageViewCell *)cellForPageAtIndex:(NSUInteger)pageIndex
{
  DZLPageViewCell *view = self.cachedCells[pageIndex];
  return (id)view == [NSNull null] ? nil : view;
}

- (void)reload
{
  self.numberOfPages = 0;
  NSUInteger currentViewIndex = self.currentInnerPageIndex;
  NSUInteger numberOfViews = self.numberOfPages * self.numberOfLoops;
  if (numberOfViews == 0) {
    self.contentSize = CGSizeZero;
    return;
  }
  self.cachedCells = [NSMutableArray new];
  for (NSUInteger viewIndex = 0; viewIndex < numberOfViews; viewIndex++) {
    [self.cachedCells addObject:[NSNull null]];
  }
  [self loadVisibleViews];
  CGSize size = CGSizeMake(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
  self.frame = CGRectMake(0, 0, size.width, size.height);
  self.contentOffset = CGPointMake(currentViewIndex * size.width, 0);
  self.contentSize = CGSizeMake(numberOfViews * size.width, size.height);
}

- (void)enumerateVisibleCellsUsingBlock:(void (^)(id cell, NSInteger pageIndex, BOOL *stop))block
{
  NSUInteger numberOfPages = self.numberOfPages;
  NSUInteger currentViewIndex = self.currentInnerPageIndex;
  NSUInteger previousViewIndex = (NSUInteger)MAX((NSInteger)currentViewIndex - kNumberOfViewsToKeepInMemoryBeforeCurrent, 0);
  NSUInteger nextViewIndex = currentViewIndex + kNumberOfViewsToKeepInMemoryAfterCurrent;
  NSUInteger numberOfLoops = currentViewIndex / numberOfPages;

  __block BOOL stop = NO;
  for (NSUInteger idx = previousViewIndex; stop == NO && idx <= nextViewIndex && idx < numberOfPages * self.numberOfLoops; idx++) {
    DZLPageViewCell *cell = [self cellForPageAtIndex:idx];
    block(cell, (NSInteger)idx - (numberOfLoops * numberOfPages), &stop);
  }
}

- (DZLPageViewCell *)mostVisibleCellForPageAtIndex:(NSUInteger)pageIndex
{
  __block DZLPageViewCell *cellClosestToCurrent = nil;
  __block NSInteger distanceFromCurrent = NSIntegerMax;
  NSInteger currentPageIndex = self.currentInnerPageIndex % self.numberOfPages;
  [self enumerateVisibleCellsUsingBlock:^(DZLPageViewCell *cell, NSInteger idx, BOOL *stop) {
    if (ABS(idx - currentPageIndex) <= distanceFromCurrent && idx % (NSInteger)self.numberOfPages == (NSInteger)pageIndex) {
      cellClosestToCurrent = cell;
      distanceFromCurrent = ABS(idx - currentPageIndex);
    }
  }];
  return cellClosestToCurrent;
}


#pragma mark - loading and unloading views

- (void)loadVisibleViews
{
  NSUInteger currentViewIndex = self.currentInnerPageIndex;
  NSUInteger previousViewIndex = (NSUInteger)MAX((NSInteger)currentViewIndex - kNumberOfViewsToKeepInMemoryBeforeCurrent, 0);
  NSUInteger nextViewIndex = currentViewIndex + kNumberOfViewsToKeepInMemoryAfterCurrent;

  NSUInteger numberOfPages = self.numberOfPages;
  if (self.previouslyLoadedCurrentPageIndex != (NSInteger)currentViewIndex) {
    for(NSUInteger idx = 0 ; idx < self.cachedCells.count ; idx++ ){
      DZLPageViewCell *cell = self.cachedCells[idx];
      if (idx >= previousViewIndex && idx <= nextViewIndex) {
        [self loadViewAtIndex:idx];
      } else {
        if ((id)cell != [NSNull null]) {
          [cell removeFromSuperview];
        }
        self.cachedCells[idx] = [NSNull null];
      }
    }
  }

  self.previouslyLoadedCurrentPageIndex = currentViewIndex;

  // need to set the frame accordingly for each visible cell
  NSUInteger currentPageIndex = self.currentInnerPageIndex;
  DZLPageViewCell *currentCell = [self cellForPageAtIndex:currentPageIndex];
  CGFloat scrollPercentage = self.scrollOffsetX;

  BOOL canSizesVary = [self.dataSource respondsToSelector:@selector(pageView:sizeOfCellForPageAtIndex:)];

  if (!canSizesVary) return;

  CGFloat offsetX = [self horizontalOffsetForPageAtIndex:currentPageIndex] + CGRectGetWidth(currentCell.frame) / 2 - scrollPercentage * CGRectGetWidth(currentCell.frame);
  CGFloat diffX = self.contentOffset.x + CGRectGetWidth(self.bounds) / 2 - offsetX;

  for (NSUInteger i = previousViewIndex; i <= nextViewIndex && i < numberOfPages * self.numberOfLoops; i++) {
    DZLPageViewCell *cell = [self cellForPageAtIndex:i];
    CGRect frame = cell.frame;
    frame.origin.x = floorf([self horizontalOffsetForPageAtIndex:i] + diffX);
    cell.frame = frame;
  }
}

- (void)loadViewAtIndex:(NSUInteger)viewIndex
{
  DZLPageViewCell *view = self.cachedCells[viewIndex];
  if ((id)view == [NSNull null]) {
    NSUInteger externalIndex = viewIndex % self.numberOfPages;
    view = [self.dataSource pageView:self cellForPageAtIndex:externalIndex];
    self.cachedCells[viewIndex] = view;
  }


  __weak typeof(self) weakSelf = self;
  view.tapHandlerBlock = ^{
    if ([weakSelf.delegate respondsToSelector:@selector(pageView:didTapCellForPageAtIndex:)]) {
      NSUInteger externalPageIndex = viewIndex % weakSelf.numberOfPages;
      [weakSelf.delegate pageView:weakSelf didTapCellForPageAtIndex:externalPageIndex];
    }
  };

  CGRect frame = self.bounds;
  frame.size = [self sizeOfCellForPageAtIndex:viewIndex];
  frame.origin.x = CGRectGetWidth(frame) * viewIndex;
  view.frame = frame;

  if (view.superview == nil) {
    [self addSubview:view];
  }
}


#pragma mark - helpers

- (CGFloat)scrollOffsetX
{
  CGFloat viewWidth = CGRectGetWidth(self.bounds);
  CGFloat viewScrollOffsetX = self.currentInnerPageIndex * viewWidth - self.contentOffset.x;
  return viewWidth == 0 ? 0 : viewScrollOffsetX / viewWidth;
}

- (NSUInteger)numberOfLoops
{
  return self.shouldLoopScroll ? kNumberOfLoopsIfInfinite : 1;
}


- (CGFloat)horizontalOffsetForPageAtIndex:(NSUInteger)pageIndex
{
  NSUInteger externalIndex = pageIndex % self.numberOfPages;
  NSUInteger loops = pageIndex / self.numberOfPages;
  CGFloat extraOffset = 0;
  if (loops >= 1) {
    CGFloat totalWidth = [self horizontalOffsetForPageAtIndex:self.numberOfPages - 1] + [self sizeOfCellForPageAtIndex:self.numberOfPages - 1].width;
    extraOffset = loops * totalWidth;
  }
  if (self.horizontalOffsetByPageIndex[externalIndex] != [NSNull null]) {
    return [self.horizontalOffsetByPageIndex[externalIndex] floatValue] + extraOffset;
  }
  CGFloat offsetX = 0;
  for (NSUInteger i = 0; i < externalIndex; i++) {
    offsetX += [self sizeOfCellForPageAtIndex:i].width;
  }
  self.horizontalOffsetByPageIndex[externalIndex] = @(offsetX);
  return offsetX;
}

- (CGSize)sizeOfCellForPageAtIndex:(NSUInteger)pageIndex
{
  NSUInteger externalIndex = pageIndex % self.numberOfPages;
  if (self.cellSizeByPageIndex[externalIndex] != [NSNull null]) {
    return [self.cellSizeByPageIndex[externalIndex] CGSizeValue];
  }
  CGSize size = self.bounds.size;
  if ([self.dataSource respondsToSelector:@selector(pageView:sizeOfCellForPageAtIndex:)]) {
    size = [self.dataSource pageView:nil sizeOfCellForPageAtIndex:externalIndex];
  }
  self.cellSizeByPageIndex[externalIndex] = [NSValue valueWithCGSize:size];
  return size;
}


#pragma mark - lazy init properties

- (NSMutableArray *)horizontalOffsetByPageIndex
{
  if (_horizontalOffsetByPageIndex != nil) return _horizontalOffsetByPageIndex;
  _horizontalOffsetByPageIndex = [NSMutableArray array];
  for (NSUInteger i = 0; i < self.numberOfPages; i++) {
    _horizontalOffsetByPageIndex[i] = [NSNull null];
  }
  return _horizontalOffsetByPageIndex;
}

- (NSMutableArray *)cellSizeByPageIndex
{
  if (_cellSizeByPageIndex != nil) return _cellSizeByPageIndex;
  _cellSizeByPageIndex = [NSMutableArray array];
  for (NSUInteger i = 0; i < self.numberOfPages; i++) {
    _cellSizeByPageIndex[i] = [NSNull null];
  }
  return _cellSizeByPageIndex;
}

@end
