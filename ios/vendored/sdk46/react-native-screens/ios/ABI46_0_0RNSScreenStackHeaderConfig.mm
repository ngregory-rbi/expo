#ifdef RN_FABRIC_ENABLED
#import <ABI46_0_0React/ABI46_0_0RCTConversions.h>
#import <ABI46_0_0React/UIView+ABI46_0_0React.h>
#import <react/renderer/components/rnscreens/ComponentDescriptors.h>
#import <react/renderer/components/rnscreens/EventEmitters.h>
#import <react/renderer/components/rnscreens/Props.h>
#import <react/renderer/components/rnscreens/ABI46_0_0RCTComponentViewHelpers.h>
#import "ABI46_0_0RCTFabricComponentsPlugins.h"
#else
#import <ABI46_0_0React/ABI46_0_0RCTBridge.h>
#import <ABI46_0_0React/ABI46_0_0RCTImageLoader.h>
#import <ABI46_0_0React/ABI46_0_0RCTImageSource.h>
#import <ABI46_0_0React/ABI46_0_0RCTImageView.h>
#import <ABI46_0_0React/ABI46_0_0RCTShadowView.h>
#import <ABI46_0_0React/ABI46_0_0RCTUIManager.h>
#import <ABI46_0_0React/ABI46_0_0RCTUIManagerUtils.h>
#endif
#import <ABI46_0_0React/ABI46_0_0RCTFont.h>
#import "ABI46_0_0RNSScreen.h"
#import "ABI46_0_0RNSScreenStackHeaderConfig.h"
#import "ABI46_0_0RNSSearchBar.h"
#import "ABI46_0_0RNSUIBarButtonItem.h"

#ifdef RN_FABRIC_ENABLED
#else
// Some RN private method hacking below. Couldn't figure out better way to access image data
// of a given ABI46_0_0RCTImageView. See more comments in the code section processing SubviewTypeBackButton
@interface ABI46_0_0RCTImageView (Private)
- (UIImage *)image;
@end

@interface ABI46_0_0RCTImageLoader (Private)
- (id<ABI46_0_0RCTImageCache>)imageCache;
@end
#endif

@implementation ABI46_0_0RNSScreenStackHeaderConfig {
  NSMutableArray<ABI46_0_0RNSScreenStackHeaderSubview *> *_ABI46_0_0ReactSubviews;
#ifdef RN_FABRIC_ENABLED
  BOOL _initialPropsSet;
#else
#endif
}

#ifdef RN_FABRIC_ENABLED
- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigProps>();
    _props = defaultProps;
    self.hidden = YES;
    _show = YES;
    _translucent = NO;
    _ABI46_0_0ReactSubviews = [NSMutableArray new];
  }
  return self;
}
#else
- (instancetype)init
{
  if (self = [super init]) {
    self.hidden = YES;
    _translucent = YES;
    _ABI46_0_0ReactSubviews = [NSMutableArray new];
  }
  return self;
}
#endif

- (UIView *)ABI46_0_0ReactSuperview
{
  return _screenView;
}

- (NSArray<UIView *> *)ABI46_0_0ReactSubviews
{
  return _ABI46_0_0ReactSubviews;
}

- (void)removeFromSuperview
{
  [super removeFromSuperview];
  _screenView = nil;
}

// this method is never invoked by the system since this view
// is not added to native view hierarchy so we can apply our logic
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  for (ABI46_0_0RNSScreenStackHeaderSubview *subview in _ABI46_0_0ReactSubviews) {
    if (subview.type == ABI46_0_0RNSScreenStackHeaderSubviewTypeLeft || subview.type == ABI46_0_0RNSScreenStackHeaderSubviewTypeRight) {
      // we wrap the headerLeft/Right component in a UIBarButtonItem
      // so we need to use the only subview of it to retrieve the correct view
      UIView *headerComponent = subview.subviews.firstObject;
      // we convert the point to ABI46_0_0RNSScreenStackView since it always contains the header inside it
      CGPoint convertedPoint = [_screenView.ABI46_0_0ReactSuperview convertPoint:point toView:headerComponent];

      UIView *hitTestResult = [headerComponent hitTest:convertedPoint withEvent:event];
      if (hitTestResult != nil) {
        return hitTestResult;
      }
    }
  }
  return nil;
}

- (void)updateViewControllerIfNeeded
{
  UIViewController *vc = _screenView.controller;
  UINavigationController *nav = (UINavigationController *)vc.parentViewController;
  UIViewController *nextVC = nav.visibleViewController;
  if (nav.transitionCoordinator != nil) {
    // if navigator is performing transition instead of allowing to update of `visibleConttroller`
    // we look at `topController`. This is because during transitiong the `visibleController` won't
    // point to the controller that is going to be revealed after transition. This check fixes the
    // problem when config gets updated while the transition is ongoing.
    nextVC = nav.topViewController;
  }

  // we want updates sent to the VC below modal too since it is also visible
  BOOL isPresentingVC = vc.presentedViewController == nextVC;

  BOOL isInFullScreenModal = nav == nil && _screenView.stackPresentation == ABI46_0_0RNSScreenStackPresentationFullScreenModal;
  // if nav is nil, it means we can be in a fullScreen modal, so there is no nextVC, but we still want to update
  if (vc != nil && (nextVC == vc || isInFullScreenModal || isPresentingVC)) {
    [ABI46_0_0RNSScreenStackHeaderConfig updateViewController:self.screenView.controller withConfig:self animated:YES];
  }
}

- (void)layoutNavigationControllerView
{
  // We need to layout navigation controller view after translucent prop changes, because otherwise
  // frame of ABI46_0_0RNSScreen will not be changed and screen content will remain the same size.
  // For more details look at https://github.com/software-mansion/react-native-screens/issues/1158
  UIViewController *vc = _screenView.controller;
  UINavigationController *navctr = vc.navigationController;
  [navctr.view setNeedsLayout];
}

+ (void)setAnimatedConfig:(UIViewController *)vc withConfig:(ABI46_0_0RNSScreenStackHeaderConfig *)config
{
  UINavigationBar *navbar = ((UINavigationController *)vc.parentViewController).navigationBar;
  // It is workaround for loading custom back icon when transitioning from a screen without header to the screen which
  // has one. This action fails when navigating to the screen with header for the second time and loads default back
  // button. It looks like changing the tint color of navbar triggers an update of the items belonging to it and it
  // seems to load the custom back image so we change the tint color's alpha by a very small amount and then set it to
  // the one it should have.
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && defined(__IPHONE_14_0) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0
  // it brakes the behavior of `headerRight` in iOS 14, where the bug desribed above seems to be fixed, so we do nothing
  // in iOS 14
  if (@available(iOS 14.0, *)) {
  } else
#endif
  {
    [navbar setTintColor:[config.color colorWithAlphaComponent:CGColorGetAlpha(config.color.CGColor) - 0.01]];
  }
  [navbar setTintColor:config.color];

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && defined(__IPHONE_13_0) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
  if (@available(iOS 13.0, *)) {
    // font customized on the navigation item level, so nothing to do here
  } else
#endif
  {
    BOOL hideShadow = config.hideShadow;

    if (config.backgroundColor && CGColorGetAlpha(config.backgroundColor.CGColor) == 0.) {
      [navbar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
      [navbar setBarTintColor:[UIColor clearColor]];
      hideShadow = YES;
    } else {
      [navbar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
      [navbar setBarTintColor:config.backgroundColor];
    }
    [navbar setTranslucent:config.translucent];
    [navbar setValue:@(hideShadow ? YES : NO) forKey:@"hidesShadow"];

    if (config.titleFontFamily || config.titleFontSize || config.titleFontWeight || config.titleColor) {
      NSMutableDictionary *attrs = [NSMutableDictionary new];

      if (config.titleColor) {
        attrs[NSForegroundColorAttributeName] = config.titleColor;
      }

      NSString *family = config.titleFontFamily ?: nil;
      NSNumber *size = config.titleFontSize ?: @17;
      NSString *weight = config.titleFontWeight ?: nil;
      if (family || weight) {
        attrs[NSFontAttributeName] = [ABI46_0_0RCTFont updateFont:nil
                                              withFamily:family
                                                    size:size
                                                  weight:weight
                                                   style:nil
                                                 variant:nil
                                         scaleMultiplier:1.0];
      } else {
        attrs[NSFontAttributeName] = [UIFont boldSystemFontOfSize:[size floatValue]];
      }
      [navbar setTitleTextAttributes:attrs];
    }

#if !TARGET_OS_TV
    if (@available(iOS 11.0, *)) {
      if (config.largeTitle &&
          (config.largeTitleFontFamily || config.largeTitleFontSize || config.largeTitleFontWeight ||
           config.largeTitleColor || config.titleColor)) {
        NSMutableDictionary *largeAttrs = [NSMutableDictionary new];
        if (config.largeTitleColor || config.titleColor) {
          largeAttrs[NSForegroundColorAttributeName] =
              config.largeTitleColor ? config.largeTitleColor : config.titleColor;
        }
        NSString *largeFamily = config.largeTitleFontFamily ?: nil;
        NSNumber *largeSize = config.largeTitleFontSize ?: @34;
        NSString *largeWeight = config.largeTitleFontWeight ?: nil;
        if (largeFamily || largeWeight) {
          largeAttrs[NSFontAttributeName] = [ABI46_0_0RCTFont updateFont:nil
                                                     withFamily:largeFamily
                                                           size:largeSize
                                                         weight:largeWeight
                                                          style:nil
                                                        variant:nil
                                                scaleMultiplier:1.0];
        } else {
          largeAttrs[NSFontAttributeName] = [UIFont systemFontOfSize:[largeSize floatValue] weight:UIFontWeightBold];
        }
        [navbar setLargeTitleTextAttributes:largeAttrs];
      }
    }
#endif
  }
}

+ (void)setTitleAttibutes:(NSDictionary *)attrs forButton:(UIBarButtonItem *)button
{
  [button setTitleTextAttributes:attrs forState:UIControlStateNormal];
  [button setTitleTextAttributes:attrs forState:UIControlStateHighlighted];
  [button setTitleTextAttributes:attrs forState:UIControlStateDisabled];
  [button setTitleTextAttributes:attrs forState:UIControlStateSelected];
  [button setTitleTextAttributes:attrs forState:UIControlStateFocused];
}

+ (UIImage *)loadBackButtonImageInViewController:(UIViewController *)vc withConfig:(ABI46_0_0RNSScreenStackHeaderConfig *)config
{
#ifdef RN_FABRIC_ENABLED
  @throw([NSException exceptionWithName:@"UNIMPLEMENTED" reason:@"Implement" userInfo:nil]);
#else
  BOOL hasBackButtonImage = NO;
  for (ABI46_0_0RNSScreenStackHeaderSubview *subview in config.ABI46_0_0ReactSubviews) {
    if (subview.type == ABI46_0_0RNSScreenStackHeaderSubviewTypeBackButton && subview.subviews.count > 0) {
      hasBackButtonImage = YES;
      ABI46_0_0RCTImageView *imageView = subview.subviews[0];
      if (imageView.image == nil) {
        // This is yet another workaround for loading custom back icon. It turns out that under
        // certain circumstances image attribute can be null despite the app running in production
        // mode (when images are loaded from the filesystem). This can happen because image attribute
        // is reset when image view is detached from window, and also in some cases initialization
        // does not populate the frame of the image view before the loading start. The latter result
        // in the image attribute not being updated. We manually set frame to the size of an image
        // in order to trigger proper reload that'd update the image attribute.
        ABI46_0_0RCTImageSource *source = imageView.imageSources[0];
        [imageView ABI46_0_0ReactSetFrame:CGRectMake(
                                     imageView.frame.origin.x,
                                     imageView.frame.origin.y,
                                     source.size.width,
                                     source.size.height)];
      }
      UIImage *image = imageView.image;
      // IMPORTANT!!!
      // image can be nil in DEV MODE ONLY
      //
      // It is so, because in dev mode images are loaded over HTTP from the packager. In that case
      // we first check if image is already loaded in cache and if it is, we take it from cache and
      // display immediately. Otherwise we wait for the transition to finish and retry updating
      // header config.
      // Unfortunately due to some problems in UIKit we cannot update the image while the screen
      // transition is ongoing. This results in the settings being reset after the transition is done
      // to the state from before the transition.
      if (image == nil) {
        // in DEV MODE we try to load from cache (we use private API for that as it is not exposed
        // publically in headers).
        ABI46_0_0RCTImageSource *source = imageView.imageSources[0];
        ABI46_0_0RCTImageLoader *imageloader = [subview.bridge moduleForClass:[ABI46_0_0RCTImageLoader class]];
        image = [imageloader.imageCache imageForUrl:source.request.URL.absoluteString
                                               size:source.size
                                              scale:source.scale
                                         resizeMode:imageView.resizeMode];
      }
      if (image == nil) {
        // This will be triggered if the image is not in the cache yet. What we do is we wait until
        // the end of transition and run header config updates again. We could potentially wait for
        // image on load to trigger, but that would require even more private method hacking.
        if (vc.transitionCoordinator) {
          [vc.transitionCoordinator
              animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
                // nothing, we just want completion
              }
              completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
          // in order for new back button image to be loaded we need to trigger another change
          // in back button props that'd make UIKit redraw the button. Otherwise the changes are
          // not reflected. Here we change back button visibility which is then immediately restored
#if !TARGET_OS_TV
                vc.navigationItem.hidesBackButton = YES;
#endif
                [config updateViewControllerIfNeeded];
              }];
        }
        return [UIImage new];
      } else {
        return image;
      }
    }
  }
#endif // RN_FABRIC_ENABLED
  return nil;
}

+ (void)willShowViewController:(UIViewController *)vc
                      animated:(BOOL)animated
                    withConfig:(ABI46_0_0RNSScreenStackHeaderConfig *)config
{
  [self updateViewController:vc withConfig:config animated:animated];
}

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && defined(__IPHONE_13_0) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
+ (UINavigationBarAppearance *)buildAppearance:(UIViewController *)vc
                                    withConfig:(ABI46_0_0RNSScreenStackHeaderConfig *)config API_AVAILABLE(ios(13.0))
{
  UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];

  if (config.backgroundColor && CGColorGetAlpha(config.backgroundColor.CGColor) == 0.) {
    // transparent background color
    [appearance configureWithTransparentBackground];
  } else {
    [appearance configureWithOpaqueBackground];
  }

  // set background color if specified
  if (config.backgroundColor) {
    appearance.backgroundColor = config.backgroundColor;
  }

  // TODO: implement blurEffect on Fabric
#ifdef RN_FABRIC_ENABLED
#else
  if (config.blurEffect) {
    appearance.backgroundEffect = [UIBlurEffect effectWithStyle:config.blurEffect];
  }
#endif

  if (config.hideShadow) {
    appearance.shadowColor = nil;
  }

  if (config.titleFontFamily || config.titleFontSize || config.titleFontWeight || config.titleColor) {
    NSMutableDictionary *attrs = [NSMutableDictionary new];

    if (config.titleColor) {
      attrs[NSForegroundColorAttributeName] = config.titleColor;
    }

    NSString *family = config.titleFontFamily ?: nil;
    NSNumber *size = config.titleFontSize ?: @17;
    NSString *weight = config.titleFontWeight ?: nil;
    if (family || weight) {
      attrs[NSFontAttributeName] = [ABI46_0_0RCTFont updateFont:nil
                                            withFamily:config.titleFontFamily
                                                  size:size
                                                weight:weight
                                                 style:nil
                                               variant:nil
                                       scaleMultiplier:1.0];
    } else {
      attrs[NSFontAttributeName] = [UIFont boldSystemFontOfSize:[size floatValue]];
    }
    appearance.titleTextAttributes = attrs;
  }

  if (config.largeTitleFontFamily || config.largeTitleFontSize || config.largeTitleFontWeight ||
      config.largeTitleColor || config.titleColor) {
    NSMutableDictionary *largeAttrs = [NSMutableDictionary new];

    if (config.largeTitleColor || config.titleColor) {
      largeAttrs[NSForegroundColorAttributeName] = config.largeTitleColor ? config.largeTitleColor : config.titleColor;
    }

    NSString *largeFamily = config.largeTitleFontFamily ?: nil;
    NSNumber *largeSize = config.largeTitleFontSize ?: @34;
    NSString *largeWeight = config.largeTitleFontWeight ?: nil;
    if (largeFamily || largeWeight) {
      largeAttrs[NSFontAttributeName] = [ABI46_0_0RCTFont updateFont:nil
                                                 withFamily:largeFamily
                                                       size:largeSize
                                                     weight:largeWeight
                                                      style:nil
                                                    variant:nil
                                            scaleMultiplier:1.0];
    } else {
      largeAttrs[NSFontAttributeName] = [UIFont systemFontOfSize:[largeSize floatValue] weight:UIFontWeightBold];
    }

    appearance.largeTitleTextAttributes = largeAttrs;
  }

#ifdef RN_FABRIC_ENABLED
  [appearance setBackIndicatorImage:nil transitionMaskImage:nil];
#else
  UIImage *backButtonImage = [self loadBackButtonImageInViewController:vc withConfig:config];
  if (backButtonImage) {
    [appearance setBackIndicatorImage:backButtonImage transitionMaskImage:backButtonImage];
  } else if (appearance.backIndicatorImage) {
    [appearance setBackIndicatorImage:nil transitionMaskImage:nil];
  }
#endif // RN_FABRIC_ENABLED
  return appearance;
}
#endif

+ (void)updateViewController:(UIViewController *)vc
                  withConfig:(ABI46_0_0RNSScreenStackHeaderConfig *)config
                    animated:(BOOL)animated
{
  UINavigationItem *navitem = vc.navigationItem;
  UINavigationController *navctr = (UINavigationController *)vc.parentViewController;

  NSUInteger currentIndex = [navctr.viewControllers indexOfObject:vc];
  UINavigationItem *prevItem =
      currentIndex > 0 ? [navctr.viewControllers objectAtIndex:currentIndex - 1].navigationItem : nil;

  BOOL wasHidden = navctr.navigationBarHidden;
#ifdef RN_FABRIC_ENABLED
  BOOL shouldHide = config == nil || !config.show;
#else
  BOOL shouldHide = config == nil || config.hide;
#endif

  if (!shouldHide && !config.translucent) {
    // when nav bar is not translucent we chage edgesForExtendedLayout to avoid system laying out
    // the screen underneath navigation controllers
    vc.edgesForExtendedLayout = UIRectEdgeNone;
  } else {
    // system default is UIRectEdgeAll
    vc.edgesForExtendedLayout = UIRectEdgeAll;
  }

  [navctr setNavigationBarHidden:shouldHide animated:animated];

  if ((config.direction == UISemanticContentAttributeForceLeftToRight ||
       config.direction == UISemanticContentAttributeForceRightToLeft) &&
      // iOS 12 cancels swipe gesture when direction is changed. See #1091
      navctr.view.semanticContentAttribute != config.direction) {
    navctr.view.semanticContentAttribute = config.direction;
    navctr.navigationBar.semanticContentAttribute = config.direction;
  }

  if (shouldHide) {
    return;
  }

  navitem.title = config.title;
#if !TARGET_OS_TV
  if (config.backTitle != nil || config.backTitleFontFamily || config.backTitleFontSize ||
      config.disableBackButtonMenu) {
    ABI46_0_0RNSUIBarButtonItem *backBarButtonItem = [[ABI46_0_0RNSUIBarButtonItem alloc] initWithTitle:config.backTitle ?: prevItem.title
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:nil
                                                                               action:nil];

    [backBarButtonItem setMenuHidden:config.disableBackButtonMenu];

    prevItem.backBarButtonItem = backBarButtonItem;
    if (config.backTitleFontFamily || config.backTitleFontSize) {
      NSMutableDictionary *attrs = [NSMutableDictionary new];
      NSNumber *size = config.backTitleFontSize ?: @17;
      if (config.backTitleFontFamily) {
        attrs[NSFontAttributeName] = [ABI46_0_0RCTFont updateFont:nil
                                              withFamily:config.backTitleFontFamily
                                                    size:size
                                                  weight:nil
                                                   style:nil
                                                 variant:nil
                                         scaleMultiplier:1.0];
      } else {
        attrs[NSFontAttributeName] = [UIFont boldSystemFontOfSize:[size floatValue]];
      }
      [self setTitleAttibutes:attrs forButton:prevItem.backBarButtonItem];
    }
  } else {
    prevItem.backBarButtonItem = nil;
  }

  if (@available(iOS 11.0, *)) {
    if (config.largeTitle) {
      navctr.navigationBar.prefersLargeTitles = YES;
    }
    navitem.largeTitleDisplayMode =
        config.largeTitle ? UINavigationItemLargeTitleDisplayModeAlways : UINavigationItemLargeTitleDisplayModeNever;
  }
#endif

#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && defined(__IPHONE_13_0) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
  if (@available(iOS 13.0, tvOS 13.0, *)) {
    UINavigationBarAppearance *appearance = [self buildAppearance:vc withConfig:config];
    navitem.standardAppearance = appearance;
    navitem.compactAppearance = appearance;

    UINavigationBarAppearance *scrollEdgeAppearance =
        [[UINavigationBarAppearance alloc] initWithBarAppearance:appearance];
    if (config.largeTitleBackgroundColor != nil) {
      scrollEdgeAppearance.backgroundColor = config.largeTitleBackgroundColor;
    }
    if (config.largeTitleHideShadow) {
      scrollEdgeAppearance.shadowColor = nil;
    }
    navitem.scrollEdgeAppearance = scrollEdgeAppearance;
  } else
#endif
  {
#if !TARGET_OS_TV
    // updating backIndicatotImage does not work when called during transition. On iOS pre 13 we need
    // to update it before the navigation starts.
    UIImage *backButtonImage = [self loadBackButtonImageInViewController:vc withConfig:config];
    if (backButtonImage) {
      navctr.navigationBar.backIndicatorImage = backButtonImage;
      navctr.navigationBar.backIndicatorTransitionMaskImage = backButtonImage;
    } else if (navctr.navigationBar.backIndicatorImage) {
      navctr.navigationBar.backIndicatorImage = nil;
      navctr.navigationBar.backIndicatorTransitionMaskImage = nil;
    }
#endif
  }
#if !TARGET_OS_TV
  navitem.hidesBackButton = config.hideBackButton;
#endif
  navitem.leftBarButtonItem = nil;
  navitem.rightBarButtonItem = nil;
  navitem.titleView = nil;

  for (ABI46_0_0RNSScreenStackHeaderSubview *subview in config.ABI46_0_0ReactSubviews) {
    switch (subview.type) {
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeLeft: {
#if !TARGET_OS_TV
        navitem.leftItemsSupplementBackButton = config.backButtonInCustomView;
#endif
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:subview];
        navitem.leftBarButtonItem = buttonItem;
        break;
      }
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeRight: {
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithCustomView:subview];
        navitem.rightBarButtonItem = buttonItem;
        break;
      }
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeCenter:
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeTitle: {
        navitem.titleView = subview;
        break;
      }
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeSearchBar: {
        if (subview.subviews == nil || [subview.subviews count] == 0) {
          ABI46_0_0RCTLogWarn(
              @"Failed to attach search bar to the header. We recommend using `useLayoutEffect` when managing "
               "searchBar properties dynamically. \n\nSee: github.com/software-mansion/react-native-screens/issues/1188");
          break;
        }

        if ([subview.subviews[0] isKindOfClass:[ABI46_0_0RNSSearchBar class]]) {
#if !TARGET_OS_TV
          if (@available(iOS 11.0, *)) {
            ABI46_0_0RNSSearchBar *searchBar = subview.subviews[0];
            navitem.searchController = searchBar.controller;
            navitem.hidesSearchBarWhenScrolling = searchBar.hideWhenScrolling;
          }
#endif
        }
        break;
      }
      case ABI46_0_0RNSScreenStackHeaderSubviewTypeBackButton: {
#ifdef RN_FABRIC_ENABLED
        ABI46_0_0RCTLogWarn(@"Back button subivew is not yet Fabric compatible in react-native-screens");
#endif
        break;
      }
    }
  }

  if (animated && vc.transitionCoordinator != nil &&
      vc.transitionCoordinator.presentationStyle == UIModalPresentationNone && !wasHidden) {
    // when there is an ongoing transition we may need to update navbar setting in animation block
    // using animateAlongsideTransition. However, we only do that given the transition is not a modal
    // transition (presentationStyle == UIModalPresentationNone) and that the bar was not previously
    // hidden. This is because both for modal transitions and transitions from screen with hidden bar
    // the transition animation block does not get triggered. This is ok, because with both of those
    // types of transitions there is no "shared" navigation bar that needs to be updated in an animated
    // way.
    [vc.transitionCoordinator
        animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
          [self setAnimatedConfig:vc withConfig:config];
        }
        completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
          if ([context isCancelled]) {
            UIViewController *fromVC = [context viewControllerForKey:UITransitionContextFromViewControllerKey];
            ABI46_0_0RNSScreenStackHeaderConfig *config = nil;
            for (UIView *subview in fromVC.view.ABI46_0_0ReactSubviews) {
              if ([subview isKindOfClass:[ABI46_0_0RNSScreenStackHeaderConfig class]]) {
                config = (ABI46_0_0RNSScreenStackHeaderConfig *)subview;
                break;
              }
            }
            [self setAnimatedConfig:fromVC withConfig:config];
          }
        }];
  } else {
    [self setAnimatedConfig:vc withConfig:config];
  }
}

- (void)insertABI46_0_0ReactSubview:(ABI46_0_0RNSScreenStackHeaderSubview *)subview atIndex:(NSInteger)atIndex
{
  [_ABI46_0_0ReactSubviews insertObject:subview atIndex:atIndex];
  subview.ABI46_0_0ReactSuperview = self;
}

- (void)removeABI46_0_0ReactSubview:(ABI46_0_0RNSScreenStackHeaderSubview *)subview
{
  [_ABI46_0_0ReactSubviews removeObject:subview];
}

- (void)didUpdateABI46_0_0ReactSubviews
{
  [super didUpdateABI46_0_0ReactSubviews];
  [self updateViewControllerIfNeeded];
}

#ifdef RN_FABRIC_ENABLED
#pragma mark - Fabric specific

- (void)mountChildComponentView:(UIView<ABI46_0_0RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if (![childComponentView isKindOfClass:[ABI46_0_0RNSScreenStackHeaderSubview class]]) {
    ABI46_0_0RCTLogError(@"ScreenStackHeader only accepts children of type ScreenStackHeaderSubview");
    return;
  }

  ABI46_0_0RCTAssert(
      childComponentView.superview == nil,
      @"Attempt to mount already mounted component view. (parent: %@, child: %@, index: %@, existing parent: %@)",
      self,
      childComponentView,
      @(index),
      @([childComponentView.superview tag]));

  //  [_ABI46_0_0ReactSubviews insertObject:(ABI46_0_0RNSScreenStackHeaderSubview *)childComponentView atIndex:index];
  [self insertABI46_0_0ReactSubview:(ABI46_0_0RNSScreenStackHeaderSubview *)childComponentView atIndex:index];
  [self updateViewControllerIfNeeded];
}

- (void)unmountChildComponentView:(UIView<ABI46_0_0RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  [_ABI46_0_0ReactSubviews removeObject:(ABI46_0_0RNSScreenStackHeaderSubview *)childComponentView];
  [childComponentView removeFromSuperview];
}

#pragma mark - ABI46_0_0RCTComponentViewProtocol

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _initialPropsSet = NO;
}

+ (ABI46_0_0facebook::ABI46_0_0React::ComponentDescriptorProvider)componentDescriptorProvider
{
  return ABI46_0_0facebook::ABI46_0_0React::concreteComponentDescriptorProvider<
      ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigComponentDescriptor>();
}

- (NSNumber *)getFontSizePropValue:(int)value
{
  if (value > 0)
    return [NSNumber numberWithInt:value];
  return nil;
}

- (UISemanticContentAttribute)getDirectionPropValue:(ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigDirection)direction
{
  switch (direction) {
    case ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigDirection::Rtl:
      return UISemanticContentAttributeForceRightToLeft;
    case ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigDirection::Ltr:
      return UISemanticContentAttributeForceLeftToRight;
  }
}

- (void)updateProps:(ABI46_0_0facebook::ABI46_0_0React::Props::Shared const &)props
           oldProps:(ABI46_0_0facebook::ABI46_0_0React::Props::Shared const &)oldProps
{
  [super updateProps:props oldProps:oldProps];

  const auto &oldScreenProps =
      *std::static_pointer_cast<const ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigProps>(_props);
  const auto &newScreenProps = *std::static_pointer_cast<const ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigProps>(props);

  BOOL needsNavigationControllerLayout = !_initialPropsSet;

  if (newScreenProps.hidden != !_show) {
    _show = !newScreenProps.hidden;
    needsNavigationControllerLayout = YES;
  }

  if (newScreenProps.translucent != _translucent) {
    _translucent = newScreenProps.translucent;
    needsNavigationControllerLayout = YES;
  }

  if (newScreenProps.backButtonInCustomView != _backButtonInCustomView) {
    [self setBackButtonInCustomView:newScreenProps.backButtonInCustomView];
  }

  _title = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.title);
  if (newScreenProps.titleFontFamily != oldScreenProps.titleFontFamily) {
    _titleFontFamily = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.titleFontFamily);
  }
  _titleFontWeight = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.titleFontWeight);
  _titleFontSize = [self getFontSizePropValue:newScreenProps.titleFontSize];
  _hideShadow = newScreenProps.hideShadow;

  _largeTitle = newScreenProps.largeTitle;
  if (newScreenProps.largeTitleFontFamily != oldScreenProps.largeTitleFontFamily) {
    _largeTitleFontFamily = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.largeTitleFontFamily);
  }
  _largeTitleFontWeight = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.largeTitleFontWeight);
  _largeTitleFontSize = [self getFontSizePropValue:newScreenProps.largeTitleFontSize];
  _largeTitleHideShadow = newScreenProps.largeTitleHideShadow;

  _backTitle = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.backTitle);
  if (newScreenProps.backTitleFontFamily != oldScreenProps.backTitleFontFamily) {
    _backTitleFontFamily = ABI46_0_0RCTNSStringFromStringNilIfEmpty(newScreenProps.backTitleFontFamily);
  }
  _backTitleFontSize = [self getFontSizePropValue:newScreenProps.backTitleFontSize];
  _hideBackButton = newScreenProps.hideBackButton;
  _disableBackButtonMenu = newScreenProps.disableBackButtonMenu;

  if (newScreenProps.direction != oldScreenProps.direction) {
    _direction = [self getDirectionPropValue:newScreenProps.direction];
  }

  // We cannot compare SharedColor because it is shared value.
  // We could compare color value, but it is more performant to just assign new value
  _titleColor = ABI46_0_0RCTUIColorFromSharedColor(newScreenProps.titleColor);
  _largeTitleColor = ABI46_0_0RCTUIColorFromSharedColor(newScreenProps.largeTitleColor);
  _color = ABI46_0_0RCTUIColorFromSharedColor(newScreenProps.color);
  _backgroundColor = ABI46_0_0RCTUIColorFromSharedColor(newScreenProps.backgroundColor);

  [self updateViewControllerIfNeeded];

  if (needsNavigationControllerLayout) {
    [self layoutNavigationControllerView];
  }

  _initialPropsSet = YES;
  _props = std::static_pointer_cast<ABI46_0_0facebook::ABI46_0_0React::ABI46_0_0RNSScreenStackHeaderConfigProps const>(props);
}

#else
#pragma mark - Paper specific

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  [super didSetProps:changedProps];
  [self updateViewControllerIfNeeded];
  // We need to layout navigation controller view after translucent prop changes, because otherwise
  // frame of ABI46_0_0RNSScreen will not be changed and screen content will remain the same size.
  // For more details look at https://github.com/software-mansion/react-native-screens/issues/1158
  if ([changedProps containsObject:@"translucent"]) {
    [self layoutNavigationControllerView];
  }
}

#endif
@end

#ifdef RN_FABRIC_ENABLED
Class<ABI46_0_0RCTComponentViewProtocol> ABI46_0_0RNSScreenStackHeaderConfigCls(void)
{
  return ABI46_0_0RNSScreenStackHeaderConfig.class;
}
#endif

@implementation ABI46_0_0RNSScreenStackHeaderConfigManager

ABI46_0_0RCT_EXPORT_MODULE()

- (UIView *)view
{
  return [ABI46_0_0RNSScreenStackHeaderConfig new];
}

ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(title, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(titleFontFamily, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(titleFontSize, NSNumber)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(titleFontWeight, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(titleColor, UIColor)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(backTitle, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(backTitleFontFamily, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(backTitleFontSize, NSNumber)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(backgroundColor, UIColor)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(blurEffect, UIBlurEffectStyle)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(color, UIColor)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(direction, UISemanticContentAttribute)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitle, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleFontFamily, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleFontSize, NSNumber)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleFontWeight, NSString)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleColor, UIColor)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleBackgroundColor, UIColor)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(largeTitleHideShadow, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(hideBackButton, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(hideShadow, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(backButtonInCustomView, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(disableBackButtonMenu, BOOL)
// `hidden` is an UIView property, we need to use different name internally
ABI46_0_0RCT_REMAP_VIEW_PROPERTY(hidden, hide, BOOL)
ABI46_0_0RCT_EXPORT_VIEW_PROPERTY(translucent, BOOL)

@end

@implementation ABI46_0_0RCTConvert (ABI46_0_0RNSScreenStackHeader)

+ (NSMutableDictionary *)blurEffectsForIOSVersion
{
  NSMutableDictionary *blurEffects = [NSMutableDictionary new];
  [blurEffects addEntriesFromDictionary:@{
    @"extraLight" : @(UIBlurEffectStyleExtraLight),
    @"light" : @(UIBlurEffectStyleLight),
    @"dark" : @(UIBlurEffectStyleDark),
  }];

  if (@available(iOS 10.0, *)) {
    [blurEffects addEntriesFromDictionary:@{
      @"regular" : @(UIBlurEffectStyleRegular),
      @"prominent" : @(UIBlurEffectStyleProminent),
    }];
  }
#if !TARGET_OS_TV && defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && defined(__IPHONE_13_0) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
  if (@available(iOS 13.0, *)) {
    [blurEffects addEntriesFromDictionary:@{
      @"systemUltraThinMaterial" : @(UIBlurEffectStyleSystemUltraThinMaterial),
      @"systemThinMaterial" : @(UIBlurEffectStyleSystemThinMaterial),
      @"systemMaterial" : @(UIBlurEffectStyleSystemMaterial),
      @"systemThickMaterial" : @(UIBlurEffectStyleSystemThickMaterial),
      @"systemChromeMaterial" : @(UIBlurEffectStyleSystemChromeMaterial),
      @"systemUltraThinMaterialLight" : @(UIBlurEffectStyleSystemUltraThinMaterialLight),
      @"systemThinMaterialLight" : @(UIBlurEffectStyleSystemThinMaterialLight),
      @"systemMaterialLight" : @(UIBlurEffectStyleSystemMaterialLight),
      @"systemThickMaterialLight" : @(UIBlurEffectStyleSystemThickMaterialLight),
      @"systemChromeMaterialLight" : @(UIBlurEffectStyleSystemChromeMaterialLight),
      @"systemUltraThinMaterialDark" : @(UIBlurEffectStyleSystemUltraThinMaterialDark),
      @"systemThinMaterialDark" : @(UIBlurEffectStyleSystemThinMaterialDark),
      @"systemMaterialDark" : @(UIBlurEffectStyleSystemMaterialDark),
      @"systemThickMaterialDark" : @(UIBlurEffectStyleSystemThickMaterialDark),
      @"systemChromeMaterialDark" : @(UIBlurEffectStyleSystemChromeMaterialDark),
    }];
  }
#endif
  return blurEffects;
}

ABI46_0_0RCT_ENUM_CONVERTER(
    UISemanticContentAttribute,
    (@{
      @"ltr" : @(UISemanticContentAttributeForceLeftToRight),
      @"rtl" : @(UISemanticContentAttributeForceRightToLeft),
    }),
    UISemanticContentAttributeUnspecified,
    integerValue)

ABI46_0_0RCT_ENUM_CONVERTER(UIBlurEffectStyle, ([self blurEffectsForIOSVersion]), UIBlurEffectStyleExtraLight, integerValue)

@end
