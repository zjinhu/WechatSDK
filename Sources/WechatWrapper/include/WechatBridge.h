//
//  WechatBridge.h
//  WechatOpenSDK
//
//  Created by HU on 8/19/25.
//

#import <Foundation/Foundation.h>
#import <WechatOpenSDK/WXApi.h>
#import <WechatOpenSDK/WechatAuthSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WechatBridge : NSObject
/// 单例
+ (instancetype)shareInstance;


/// 初始化微信SDK
/// @param appId 微信平台申请的appId
/// @param appSecret 微信平台申请的AppSecret
/// @param universalLink 唤起App的通用链接universalLink
- (void)initSDKWithAppId:(NSString *)appId appSecret:(NSString *)appSecret universalLink:(NSString *)universalLink;


/// 微信打开其他app的回调
/// @param url 微信启动第三方应用时传递过来的url
- (BOOL)handleOpenURL:(NSURL *)url;


/// 查看当前App是否已安装微信
- (BOOL)isWeiXinInstall;

/// 处理微信通过Universal Link启动App时传递的数据
- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

- (void)continueUserActivity:(NSUserActivity *)userActivity;
/// 调用微信登录接口
/// @param viewController 传入当前app的viewController
/// @param resultBlock 回调
- (void)sendWeixinLoginRequestWithViewController:(UIViewController *)viewController resultBlock:(void (^) (NSDictionary *userInfo))resultBlock;
@end

NS_ASSUME_NONNULL_END
