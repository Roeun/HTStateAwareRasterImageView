//
//  HTRasterView.m
//  HotelTonight
//
//  Created by Jacob Jennings on 11/29/12.
//  Copyright (c) 2012 Hotel Tonight. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import "HTRasterView.h"
#import "NSObject+HTPropertyHash.h"
#import "MSCachedAsyncViewDrawing.h"
#import "UIView+HTRaster.h"

// Uncommenting this SLOWS THINGS DOWN A LOT and will save all images to disk
//#define HT_DEBUG_SAVEFILES YES

#define HT_DEBUG_RASTERLOG YES

@interface HTRasterView ()

@property (nonatomic, assign) BOOL implementsShouldRasterize;
@property (nonatomic, assign) BOOL implementsUseMinimumSizeForCaps;
@property (nonatomic, assign) BOOL implementsCapEdgeInsets;
@property (nonatomic, assign) BOOL implementsShadowOutset;
@property (nonatomic, strong) NSOperation *drawingOperation;
@property (nonatomic, strong) NSMutableArray *descendantRasterImageViews;
@property (nonatomic, strong) UIView<HTRasterizableView> *rasterizableViewAsSubview;
@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation HTRasterView
@dynamic image;

- (id)initWithFrame:(CGRect)frame
{
    self = ([super initWithFrame:frame]);
    if (self)
    {
        _kvoEnabled = YES;
        _drawsOnMainThread = YES;
        _descendantRasterImageViews = [NSMutableArray array];
        _rasterized = YES;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.rasterizableView)
    {
        [self layoutRasterizableView];
    }
    self.rasterizableViewAsSubview.frame = self.bounds;
    [self regenerateImage:nil];
}

- (void)layoutRasterizableView;
{
    CGSize size = self.bounds.size;

    UIEdgeInsets edgeInsets = [self capEdgeInsets];

    if ([self useMinimumCapSize])
    {
        size = CGSizeMake(edgeInsets.left + edgeInsets.right + 1, edgeInsets.top + edgeInsets.bottom + 1);
    }

    self.rasterizableView.frame = (CGRect){ .origin = CGPointZero, .size = size };
}

- (void)dealloc
{
    [self removeAllObservers];
    _rasterizableView.htRasterImageView = nil;
    self.delegate = nil;
}

#pragma mark - Properties

- (void)setRasterizableView:(UIView<HTRasterizableView> *)rasterizableView
{
    [self removeAllObservers];
    _rasterizableView.htRasterImageView = nil;
    _rasterizableView = rasterizableView;
    if (!rasterizableView)
    {
        return;
    }
    _rasterizableView.htRasterImageView = self;
    [self layoutRasterizableView];
    
    self.implementsShouldRasterize = [self.rasterizableView respondsToSelector:@selector(shouldRegenerateRasterForKeyPath:change:)];
    self.implementsUseMinimumSizeForCaps = [self.rasterizableView respondsToSelector:@selector(useMinimumFrameForCaps)];
    self.implementsCapEdgeInsets = [self.rasterizableView respondsToSelector:@selector(capEdgeInsets)];
    self.implementsShadowOutset = [self.rasterizableView respondsToSelector:@selector(shadowRenderOutset)];
    
    for (NSString *propertyName in [rasterizableView keyPathsThatAffectState])
    {
        [rasterizableView addObserver:self forKeyPath:propertyName options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    }
    [self regenerateImage:nil];
}

- (void)setRasterized:(BOOL)rasterized
{
    if (_rasterized == rasterized)
    {
        return;
    }
    _rasterized = rasterized;
    if (rasterized)
    {
        [self.rasterizableViewAsSubview removeFromSuperview];
        self.rasterizableView = self.rasterizableViewAsSubview;
        self.rasterizableViewAsSubview = nil;
    }
    else
    {
        self.rasterizableViewAsSubview = self.rasterizableView;
        [self addSubview:self.rasterizableViewAsSubview];
        self.rasterizableView = nil;
        [self setNeedsLayout];
    }
}

- (UIImage *)image
{
    return self.imageView.image;
}

#pragma mark - Private

- (void)removeAllObservers;
{
    for (NSString *propertyName in [self.rasterizableView keyPathsThatAffectState])
    {
        [_rasterizableView removeObserver:self forKeyPath:propertyName];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.kvoEnabled)
    {
        return;
    }
    if (self.implementsShouldRasterize)
    {
        if (![self.rasterizableView shouldRegenerateRasterForKeyPath:keyPath change:change])
        {
            return;
        }
    }
    
    id old = change[NSKeyValueChangeOldKey];
    id new = change[NSKeyValueChangeNewKey];
    if ([new isEqual:old])
    {
        return;
    }
    [self regenerateImage:nil];
}

- (UIEdgeInsets)capEdgeInsets
{
    UIEdgeInsets edgeInsets = UIEdgeInsetsZero;
    if (self.implementsCapEdgeInsets)
    {
        edgeInsets = [self.rasterizableView capEdgeInsets];
    }
    return edgeInsets;
}

- (BOOL)useMinimumCapSize
{
    return self.implementsUseMinimumSizeForCaps && [self.rasterizableView useMinimumFrameForCaps];
}

- (void)regenerateImage:(HTSARIVVoidBlock)complete
{
    if (!self.rasterizableView)
    {
        return;
    }
    [self layoutRasterizableView];
    CGSize size = self.rasterizableView.bounds.size;
    if ((size.width < 1 || size.height < 1))
    {
        return;
    }
    CGFloat shadowRenderOutset = self.implementsShadowOutset ? [self.rasterizableView shadowRenderOutset] : 0;
    size.width += shadowRenderOutset * 2;
    size.height += shadowRenderOutset * 2;

    __block NSString *cacheKey = [self cacheKey];
    __unsafe_unretained HTRasterView *bSelf = self;

    MSCachedAsyncViewDrawingDrawBlock drawBlock = ^(CGRect frame, CGContextRef context)
    {
        if ([bSelf.delegate respondsToSelector:@selector(rasterViewWillRegenerateImage:)])
        {
            [bSelf.delegate rasterViewWillRegenerateImage:bSelf];
        }
        CGRect insetFrame = CGRectInset(frame, shadowRenderOutset, shadowRenderOutset);
        bSelf.rasterizableView.frame = insetFrame;
        [bSelf.rasterizableView drawRect:insetFrame inContext:context];
#ifdef HT_DEBUG_RASTERLOG
        NSLog(@"Key: %@\n", [cacheKey stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
#endif
    };
    
    MSCachedAsyncViewDrawingCompletionBlock completionBlock = ^(UIImage *drawnImage)
    {
        if (!drawnImage)
        {
            return;
        }
        if (drawnImage != bSelf.imageView.image)
        {
            bSelf.imageView.image = drawnImage;
            [self informFirstAncestorRasterImageViewThatWeRegenerated];
        }

        if ([bSelf.delegate respondsToSelector:@selector(rasterViewImageLoaded:)])
        {
            [bSelf.delegate rasterViewImageLoaded:bSelf];
        }
        
#ifdef HT_DEBUG_SAVEFILES
        NSString *fileName = [NSString stringWithFormat:@"/%@-%u.jpg", NSStringFromClass([bSelf.rasterizableView class]), [cacheKey hash]];
        NSData *imageData = UIImageJPEGRepresentation(drawnImage, 1);
        NSString *imagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                               stringByAppendingPathComponent:fileName];
        [imageData writeToFile:imagePath atomically:YES];
#endif
        
        if (complete) complete();
    };
    
    [self.drawingOperation cancel];
    if (!cacheKey || !cacheKey.length)
    {
        NSLog(@"No cache key?! %@, %@", self.rasterizableView, self.rasterizableViewAsSubview);
    }
    self.drawingOperation = [[MSCachedAsyncViewDrawing sharedInstance] drawViewSynchronous:self.drawsOnMainThread
                                                                              withCacheKey:cacheKey
                                                                                      size:size
                                                                           backgroundColor:[UIColor clearColor]
                                                                             capEdgeInsets:[self capEdgeInsets]
                                                                                 drawBlock:drawBlock
                                                                           completionBlock:completionBlock];
}

- (void)informFirstAncestorRasterImageViewThatWeRegenerated
{
    [[self firstAncestorRasterizableView].htRasterImageView regenerateImage:nil];
}

- (NSString *)cacheKey
{
    NSMutableString *cacheString = [[self.rasterizableView hashStringForKeyPaths:[self.rasterizableView keyPathsThatAffectState]] mutableCopy];
    for (HTRasterView *descendantRasterImageView in self.descendantRasterImageViews)
    {
        [cacheString appendString:[descendantRasterImageView cacheKey]];
    }
    return [cacheString copy];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [self regenerateImage:nil];
}

#pragma mark - Touch forwarding

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    if (!self.gestureRecognizers || ![self.gestureRecognizers count]) {
        [self.rasterizableView touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    if (!self.gestureRecognizers || ![self.gestureRecognizers count]) {
        [self.rasterizableView touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    if (!self.gestureRecognizers || ![self.gestureRecognizers count]) {
        [self.rasterizableView touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
    if (!self.gestureRecognizers || ![self.gestureRecognizers count]) {
        [self.rasterizableView touchesCancelled:touches withEvent:event];
    }
}

#pragma mark - Descendant rasterization

- (void)registerDescendantRasterView:(HTRasterView *)descendant
{
    [self.descendantRasterImageViews addObject:descendant];
    [self.descendantRasterImageViews sortUsingComparator:^NSComparisonResult(HTRasterView *obj1, HTRasterView *obj2) {
        return [NSStringFromClass([obj1.rasterizableView class]) compare:NSStringFromClass([obj2.rasterizableView class])];
    }];
    [self regenerateImage:nil];
}

- (void)unregisterDescendantRasterView:(HTRasterView *)descendant
{
    [self.descendantRasterImageViews removeObject:descendant];
}

@end
