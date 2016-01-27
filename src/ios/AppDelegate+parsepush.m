#import "AppDelegate+parsepush.h"
#import "ParsePushPlugin.h"

#import <objc/runtime.h>

@implementation AppDelegate(parsepush)
void MethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(application:didReceiveRemoteNotification:));
}

//
// noop defaults for the swizzling mechanism
//
- (void)noop_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken {}
- (void)noop_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {}


- (id)getParsePluginInstance
{
    return [self.viewController getCommandInstance:@"ParsePushPlugin"];
}

- (void)swizzled_application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
    //
    // Call existing method in case it's already defined in main project's AppDelegate
    [self swizzled_application:application didRegisterForRemoteNotificationsWithDeviceToken:newDeviceToken];
    
    //
    // Save device token
    [ParsePushPlugin saveDeviceTokenToInstallation:newDeviceToken];
}


- (void)swizzled_application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    //
    // Call existing method in case it's already defined in main project's AppDelegate
    [self swizzled_application:application didReceiveRemoteNotification:userInfo];
    
    
    //
    // format the pn payload to be just 1 level deep
    NSMutableDictionary* pnPayload = [NSMutableDictionary dictionaryWithDictionary:userInfo[@"aps"]];
    pnPayload[@"parsePushId"] = userInfo[@"parsePushId"];
    
    
    //
    // PN can either be opened by user or received directly by app:
    // PN can only be received directly by app when app is running in foreground, UIApplicationStateActive.
    // PN that arrived when app is not running or in background (UIApplicationStateInactive or UIApplicationStateBackground)
    //    must be opened by user to reach this part of the code
    ParsePushPlugin* pluginInstance = [self getParsePluginInstance];
    [pluginInstance jsCallback:pnPayload withAction:(application.applicationState == UIApplicationStateActive) ? @"RECEIVE" : @"OPEN"];
}
@end