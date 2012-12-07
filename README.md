<img src="https://raw.github.com/hoteltonight/HTDelegateProxy/master/ht-logo-black.png" alt="HotelTonight" title="HotelTonight" style="display:block; margin: 10px auto 30px auto;">

HTStateAwareRasterImageView
===========================

## Overview

HTStateAwareRasterImageView is a rasterization system that caches rendered components based on state.  The advantage over Core Animation's rasterization is that you only draw a component once for each unique state.

## Installation

This library is dependent on the MSCachedAsyncViewDrawing class by Javier Soto of MindSnacks. 
The recommended installation method is cocoapods, which handles this dependency automatically. Add this line to your Podfile:

    pod 'HTStateAwareRasterImageView'

http://cocoapods.org

## Usage

Start by conforming to the HTRasterizableView protocol.  A simple example is provided in the demo project (HTExampleRasterizableComponent).  The single required method is:

    - (NSArray *)keyPathsThatAffectState;

This is used for two purposes: <br/>
1. To key-value observe the specified key paths to trigger image regeneration <br/>
2. To generate a hash of the component's state

If your component can take advantage of UIImage caps (fixed-size corners and stretchable center), these two methods are optional on the HTRasterizableView protocol: <br/>

    - (UIEdgeInsets)capEdgeInsets;
    - (BOOL)useMinimumFrameForCaps;
    
Initialize a HTStateAwareRasterImageView and set the rasterizableView property to your HTRasterizableView, like this snippet from the demo project:

        _rasterizableComponent = [[HTExampleRasterizableComponent alloc] init];
        _stateAwareRasterImageView = [[HTStateAwareRasterImageView alloc] init];
        _stateAwareRasterImageView.rasterizableView = _rasterizableComponent;
        _stateAwareRasterImageView.delegate = self;
        [self addSubview:_stateAwareRasterImageView];

You can specify if you want drawing to occur synchronously on the main thread:

    @property (nonatomic, assign) BOOL drawsOnMainThread;

You can also turn off keypath observing if you want to manually regenerate images (use this for pre-rendering assets):

    @property (nonatomic, assign) BOOL kvoEnabled; 
    // For prerendering only
    - (void)regenerateImage:(HTSARIVVoidBlock)complete;

A delegate property is also available to let you know when it's regenerating an image, and when it gets a new image back:
    @property (atomic, assign) id<HTStateAwareRasterImageViewDelegate> delegate;

For debugging purposes, the cache key is available through this method.
    - (NSString *)cacheKey;

## Demo project

The demo project has three tabs: 

* A tableview taking advantage of HTStateAwareRasterImageView
* A tableview that displays cache key, actual size and cell-height sized cached images
* A tableview that uses the same components without rasterization

<img src="https://raw.github.com/hoteltonight/HTStateAwareRasterImageView/master/tab1.png" alt="HotelTonight" title="HotelTonight" style="display:block; margin: 10px auto 30px auto;">
<img src="https://raw.github.com/hoteltonight/HTStateAwareRasterImageView/master/tab2.png" alt="HotelTonight" title="HotelTonight" style="display:block; margin: 10px auto 30px auto;">
