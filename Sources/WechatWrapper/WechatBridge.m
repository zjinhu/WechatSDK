//
//  WechatBridge.m
//  WechatOpenSDK
//
//  Created by HU on 8/19/25.
//
#import "WechatBridge.h"
#define Weixin_GetAccessTokenURL @"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code"
#define Weixin_isAccessTokenCanUse @"https://api.weixin.qq.com/sns/auth?access_token=%@&openid=%@"
#define Weixin_UseRefreshToken @"https://api.weixin.qq.com/sns/oauth2/refresh_token?appid=%@&grant_type=refresh_token&refresh_token=%@"
#define Weixin_GetUserInformation @"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@"


@interface WechatBridge () <WXApiDelegate>

@property (nonatomic, copy) NSString *appId;

@property (nonatomic, copy) NSString *appSecret;

@property (nonatomic, strong) NSMutableDictionary * userInfo;

@property (nonatomic, copy) void (^WeChatLoginBlock) (NSDictionary *userInfo);

@property (nonatomic, copy) void (^WeChatPayResultBlock)(NSNumber *errCode);///0:支付成功 -2:中途退出 其他:支付失败

@end
@implementation WechatBridge

+ (instancetype)shareInstance {
    static WechatBridge *weChatSDK;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        weChatSDK = [[WechatBridge allocWithZone:nil] init];
    });
    return weChatSDK;
}

/// 初始化微信SDK
- (void)initSDKWithAppId:(NSString *)appId appSecret:(NSString *)appSecret universalLink:(NSString *)universalLink {
    _appId = appId;
    _appSecret = appSecret;
    [WXApi registerApp:appId universalLink:universalLink];
    _userInfo = [[NSMutableDictionary alloc] init];
}

/// 微信打开其他app的回调
- (BOOL)handleOpenURL:(NSURL *)url {
    [WXApi handleOpenURL:url delegate:self];
    return YES;
}

/// 查看微信是否安装
- (BOOL)isWeiXinInstall {
    return [WXApi isWXAppInstalled] || [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"weixin://"]] || [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"Whatapp://"]];
}

/// 处理微信通过Universal Link启动App时传递的数据
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    return [WXApi handleOpenUniversalLink:userActivity delegate:self];
    
}

- (void)continueUserActivity:(NSUserActivity *)userActivity{
    [WXApi handleOpenUniversalLink:userActivity delegate:self];
}


#pragma mark - WXApiDelegate

/// 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。可能收到的处理结果有SendMessageToWXResp、SendAuthResp等。
/// @param resp  具体的回应内容，是自动释放的
- (void)onResp:(BaseResp *)resp {
    if ([resp isKindOfClass:[SendAuthResp class]]) {// 微信登录
        if (resp.errCode == 0) {// 登录成功
            [self loginWeixinSuccessWithBaseResp:resp];
            NSLog(@"====成功====");
        }else {// 登录失败
            NSLog(@"====失败====");
        }
    }
    if ([resp isKindOfClass:[PayResp class]]) {// 微信支付
        PayResp *response = (PayResp *)resp;
        if (self.WeChatPayResultBlock) {
            self.WeChatPayResultBlock(@(response.errCode));
        }
    }
}

- (void)onReq:(BaseReq *)req {
    
}

#pragma mark - 微信登录成功获取token
- (void)loginWeixinSuccessWithBaseResp:(BaseResp *)resp {
    SendAuthResp *auth = (SendAuthResp *)resp;
    NSString *code = auth.code;
    //Weixin_AppID和Weixin_AppSecret是微信申请下发的.
    [self.userInfo setObject:@"weixin" forKey:@"oauthName"];
    NSString *str = [NSString stringWithFormat:Weixin_GetAccessTokenURL,_appId,_appSecret,code];
    __weak typeof(self)wself = self;
    [self getRequestWithUrl:[NSURL URLWithString:str] success:^(NSDictionary *responseDict) {
        NSString *access_token = responseDict[@"access_token"];
        NSString *refresh_token = responseDict[@"refresh_token"];
        NSString *openid = responseDict[@"openid"];
        NSString *unionid = [responseDict objectForKey:@"unionid"];
        if (unionid) {
            [wself.userInfo setObject:unionid forKey:@"unionid"];
        }
        [wself isAccessTokenCanUseWithAccessToken:access_token openID:openid completionHandler:^(BOOL isCanUse) {
            if (isCanUse) {
                [wself getUserInformationWithAccessToken:access_token openID:openid];
            }else{
                [wself useRefreshToken:refresh_token];
            }
        }];
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
    
}

/// 获取appstore上app的信息
- (void)getRequestWithUrl:(NSURL *)url success:(void (^) (NSDictionary *responseDict))success failure:(void (^) (NSError *error))failure {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                if (success) success(responseDict);
            }else {
                if (failure) failure(error);
            }
        });
    }];
    [dataTask resume];
}

#pragma mark - 判断access_token是否过期
- (void)isAccessTokenCanUseWithAccessToken:(NSString *)accessToken openID:(NSString *)openID completionHandler:(void(^)(BOOL isCanUse))completeHandler {
    NSString *strOfSeeAccess_tokenCanUse = [NSString stringWithFormat:Weixin_isAccessTokenCanUse, accessToken, openID];
    [self getRequestWithUrl:[NSURL URLWithString:strOfSeeAccess_tokenCanUse] success:^(NSDictionary *responseDict) {
        if ([responseDict[@"errmsg"] isEqualToString:@"ok"]) {
            completeHandler(YES);
        }else{
            completeHandler(NO);
        }
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
        completeHandler(NO);
    }];
}

#pragma mark - 若未过期,获取用户信息
- (void)getUserInformationWithAccessToken:(NSString *)access_token openID:(NSString *)openID {
    if (access_token) {
        [self.userInfo setObject:access_token forKey:@"accessToken"];
    }
    if (openID) {
        [self.userInfo setObject:openID forKey:@"openid"];
    }
    __weak typeof(self) wself = self;
    NSString *strOfGetUserInformation = [NSString stringWithFormat:Weixin_GetUserInformation, access_token, openID];
    [self getRequestWithUrl:[NSURL URLWithString:strOfGetUserInformation] success:^(NSDictionary *responseDict) {
        NSString *nickname = responseDict[@"nickname"];
        NSString *headimgurl = responseDict[@"headimgurl"];
        NSNumber *sexnumber = responseDict[@"sex"];
        NSString *sexstr = [NSString stringWithFormat:@"%@",sexnumber];
        NSString *sex;
        if ([sexstr isEqualToString:@"1"]) {
            sex = @"男";
        }else if ([sexstr isEqualToString:@"2"]){
            sex = @"女";
        }else{
            sex = @"未知";
        }
        [wself.userInfo setObject:sex forKey:@"sex"];
        if (nickname) {
            [wself.userInfo setObject:nickname forKey:@"nickname"];
        }
        if (headimgurl) {
            [wself.userInfo setObject:headimgurl forKey:@"icon"];
        }
        if (wself.WeChatLoginBlock) {
            wself.WeChatLoginBlock(wself.userInfo);
        }
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
}

#pragma mark - 若过期,使用refresh_token获取新的access_token
- (void)useRefreshToken:(NSString *)refreshToken {
    NSString *strOfUseRefreshToken = [NSString stringWithFormat:Weixin_UseRefreshToken, _appId, refreshToken];
    __weak typeof(self) wself = self;
    [self getRequestWithUrl:[NSURL URLWithString:strOfUseRefreshToken] success:^(NSDictionary *responseDict) {
        NSString *openid = responseDict[@"openid"];
        NSString *access_token = responseDict[@"access_token"];
        NSString *refresh_tokenNew = responseDict[@"refresh_token"];
        [wself isAccessTokenCanUseWithAccessToken:access_token openID:openid completionHandler:^(BOOL isCanUse) {
            if (isCanUse) {
                [wself getUserInformationWithAccessToken:access_token openID:openid];
            }else{
                [wself useRefreshToken:refresh_tokenNew];
            }
        }];
    } failure:^(NSError *error) {
        NSLog(@"请求失败--%@",error);
    }];
}

/// 调用微信登录接口
- (void)sendWeixinLoginRequestWithViewController:(UIViewController *)viewController resultBlock:(void (^)(NSDictionary * _Nonnull))resultBlock {
    _WeChatLoginBlock = resultBlock;
    SendAuthReq *req = [[SendAuthReq alloc] init];
    req.scope = @"snsapi_userinfo";
    req.state = @"WeChatLogin";
    if ([self isWeiXinInstall]) {
        [WXApi sendReq:req completion:nil];
    }else {
        [WXApi sendAuthReq:req viewController:viewController delegate:self completion:nil];
    }
}
@end
