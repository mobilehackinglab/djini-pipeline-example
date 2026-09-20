//
//  SceneDelegate.m
//  Linkliar
//
//  Created by vi on 01/10/25.
//

#import "SceneDelegate.h"
#import "ViewController.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    
    // Handle URL if app was opened via deeplink
    for (NSUserActivity *activity in connectionOptions.userActivities) {
        [self handleUserActivity:activity];
    }
    
    // Handle URL schemes
    for (NSURL *url in connectionOptions.URLContexts.allObjects.firstObject ? @[connectionOptions.URLContexts.allObjects.firstObject.URL] : @[]) {
        [self handleDeeplink:url];
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}

#pragma mark - URL Handling

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *context in URLContexts) {
        [self handleDeeplink:context.URL];
    }
}

- (void)handleUserActivity:(NSUserActivity *)userActivity {
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        [self handleDeeplink:userActivity.webpageURL];
    }
}

- (void)handleDeeplink:(NSURL *)url {
    if (!url) return;
        
    if (![url.scheme isEqualToString:@"linkliar"]) {
        return;
    }
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if ([components.host isEqualToString:@"scan"] || [components.path isEqualToString:@"/scan"]) {

        NSString *urlToScan = nil;
        for (NSURLQueryItem *queryItem in components.queryItems) {
            if ([queryItem.name isEqualToString:@"url"]) {
                urlToScan = queryItem.value;
                break;
            }
        }
        
        if (urlToScan) {
            [self performScanWithURL:urlToScan];
        }
    }
    else if ([components.host isEqualToString:@"debug"]) {
        NSString *debugString = components.query ? [NSString stringWithFormat:@"debug?%@", components.query] : @"debug";
        [self performDebugWithString:debugString];
    }
}

- (void)performScanWithURL:(NSString *)urlToScan {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootViewController = self.window.rootViewController;
        
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)rootViewController;
            rootViewController = navController.visibleViewController;
        }
        
        if ([rootViewController isKindOfClass:[ViewController class]]) {
            ViewController *viewController = (ViewController *)rootViewController;
            [viewController scanURLFromDeeplink:urlToScan];
        }
    });
}

- (void)performDebugWithString:(NSString *)debugString {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootViewController = self.window.rootViewController;
        
        if ([rootViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navController = (UINavigationController *)rootViewController;
            rootViewController = navController.visibleViewController;
        }
        
        if ([rootViewController isKindOfClass:[ViewController class]]) {
            ViewController *viewController = (ViewController *)rootViewController;
            [viewController scanURLFromDeeplink:debugString];
        }
    });
}

@end
