//
//  WechatManager.swift
//
//  Created by 狄烨 on 2025/3/13.
//

import Foundation
import WechatSDK
import WechatOpenSDK
public class WechatManager: NSObject {
    /// It use to store openid, access_token, refresh_token
    fileprivate let defaults = UserDefaults.standard

    /// A closure used to receive and process request from Third-party
    public typealias Handle = (WXResult<[String: Any], Int32>) -> Void
    /// A closure used to receive and process request from Wechat
    var completionHandler: Handle!
    var isGetCode: Bool = false

    /// 微信开放平台,注册的应用程序id
    var appid: String!
    /// 微信开放平台,注册的应用程序所对应的 Universal Links
    var universalLink: String!
    /// 微信开放平台,注册的应用程序Secret
    var appSecret: String!
    
    /// openid
    public var openid: String! {
        didSet {
            self.defaults.set(self.openid, forKey: "wechatkit_openid")
            self.defaults.synchronize()
        }
    }
    /// access token
    public var accessToken: String! {
        didSet {
            self.defaults.set(self.accessToken, forKey: "wechatkit_access_token")
            self.defaults.synchronize()
        }
    }
    /// refresh token
    public var refreshToken: String! {
        didSet {
            self.defaults.set(self.refreshToken, forKey: "wechatkit_refresh_token")
            self.defaults.synchronize()
        }
    }
    /// csrf
    public static var csrfState = "WeChatLogin"

    /// A shared instance
    public static let shared: WechatManager = {
        let instalce = WechatManager()
        instalce.openid = instalce.defaults.string(forKey: "wechatkit_openid")
        instalce.accessToken = instalce.defaults.string(forKey: "wechatkit_access_token")
        instalce.refreshToken = instalce.defaults.string(forKey: "wechatkit_refresh_token")
        return instalce
    }()

    public func initSDK(appid: String, universalLink: String, appSecret: String) {
        self.appid = appid
        self.universalLink = universalLink
        self.appSecret = appSecret
        WXApi.registerApp(appid, universalLink: universalLink)
    }
    /// 检查微信是否已被用户安装
    ///
    /// - Returns: 微信已安装返回true，未安装返回false
    public func isInstalled() -> Bool {
        return WXApi.isWXAppInstalled()
    }

    /**
     处理微信通过URL启动App时传递的数据

     需要在 application:openURL:sourceApplication:annotation:或者application:handleOpenURL中调用。

     - parameter url: 微信启动第三方应用时传递过来的URL

     - returns: 成功返回true，失败返回false
     */
    @discardableResult
    public func handleOpenURL(_ url: URL) -> Bool {
        WXApi.handleOpen(url, delegate: WechatManager.shared)
        return true
    }

    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return WXApi.handleOpenUniversalLink(userActivity, delegate: WechatManager.shared)
    }
    
    public func continueUserActivity(userActivity: NSUserActivity) {
        WXApi.handleOpenUniversalLink(userActivity, delegate: WechatManager.shared)
    }
}

// MARK: WeiChatDelegate

extension WechatManager: WXApiDelegate {

    /**
    发送一个sendReq后，收到微信的回应

    * 收到一个来自微信的处理结果。调用一次sendReq后会收到onResp。
    * 可能收到的处理结果有SendMessageToWXResp、SendAuthResp等

    - parameter resp: 具体的回应内容，是自动释放的
    */
    public func onResp(_ resp: BaseResp) {
        if 0 != resp.errCode {
            completionHandler(.failure(WXErrCodeCommon.rawValue))
            return
        }
        if let temp = resp as? SendAuthResp {
            if let code = temp.code, WechatManager.csrfState == temp.state {
                if isGetCode{
                    completionHandler(.success(["code": code]))
                    return
                }
                self.getAccessToken(code)
            } else {
                completionHandler(.failure(WXErrCodeCommon.rawValue))
            }
        }
    }

    /// 获取临时登录 code
    public func getResultCode(_ completionHandler: @escaping Handle) {
        self.completionHandler = completionHandler
        self.isGetCode = true
        self.sendAuth()
    }

}

extension WechatManager {
    /**
     微信认证

     - parameter completionHandler: 取得的token信息
     */
    public func checkAuth(_ completionHandler: @escaping Handle) {
        self.completionHandler = completionHandler
        if nil != self.openid &&
            nil != self.accessToken &&
            nil != self.refreshToken {
            self.checkToken()
        } else {
            self.sendAuth()
        }
    }
    /**
     获取微信用户基本信息
     - parameter completionHandler: 微信基本用户信息
     */
    public func getUserInfo (_ completionHandler: @escaping Handle) {
        self.completionHandler = completionHandler

        RequestController.request(WechatRoute.userinfo) { result in

            if let err = result["errcode"] as? Int32 {
//                let _ = result["errmsg"] as! String
                completionHandler(.failure(err))
                return
            }

            self.completionHandler(.success(result))
        }
    }
    /**
     退出
     */
    public func logout() {
        self.openid = ""
        self.accessToken = ""
        self.refreshToken = ""
    }
}

// MARK: - private
extension WechatManager {

    fileprivate func sendAuth() {

        let req = SendAuthReq()
        req.scope = "snsapi_userinfo"
        req.state = WechatManager.csrfState
        DispatchQueue.main.async {
            if !WXApi.isWXAppInstalled() {
                // 微信没有安装 通过短信方式认证(需要弹出一个 webview)
                WXApi.sendAuthReq(req, viewController: UIViewController.currentViewController()!, delegate: WechatManager.shared)
            } else {
                WXApi.send(req)
            }
        }
    }

    fileprivate func checkToken() {

        RequestController.request(WechatRoute.checkToken) { result in

            if !result.keys.contains("errcode") {
                self.completionHandler(.success(result))
                return
            }

            self.refreshAccessToken()
        }
    }

    func getAccessToken(_ code: String) {

        RequestController.request(WechatRoute.accessToken(code)) { result in

            if let err = result["errcode"] as? Int32 {
//                let _ = result["errmsg"] as! String
                self.completionHandler(.failure(err))
                return
            }

            self.saveOpenId(result)
        }
    }

    fileprivate func refreshAccessToken() {

        RequestController.request(WechatRoute.refreshToken) { result in

            if !result.keys.contains("errcode") {
                self.saveOpenId(result)
            } else {
                self.sendAuth()
            }
        }
    }

    fileprivate func saveOpenId(_ info: [String: Any]) {
        self.openid = info["openid"] as? String
        self.accessToken = info["access_token"] as? String
        self.refreshToken = info["refresh_token"] as? String

        self.completionHandler(.success(info))
    }
}

enum WechatRoute {
    static let baseURLString = "https://api.weixin.qq.com/sns"

    case userinfo
    case accessToken(String)
    case refreshToken
    case checkToken

    var path: String {
        switch self {
        case .userinfo:
            return "/userinfo"
        case .accessToken:
            return "/oauth2/access_token"
        case .refreshToken:
            return "/oauth2/refresh_token"
        case .checkToken:
            return "/auth"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .userinfo:
            return [
                "openid": WechatManager.shared.openid ?? "",
                "access_token": WechatManager.shared.accessToken ?? ""
            ]
        case .accessToken(let code):
            return [
                "appid": WechatManager.shared.appid,
                "secret": WechatManager.shared.appSecret,
                "code": code,
                "grant_type": "authorization_code"
            ]
        case .refreshToken:
            return [
                "appid": WechatManager.shared.appid,
                "refresh_token": WechatManager.shared.refreshToken ?? "",
                "grant_type": "refresh_token"
            ]
        case .checkToken:
            return [
                "openid": WechatManager.shared.openid ?? "",
                "access_token": WechatManager.shared.accessToken ?? ""
            ]
        }
    }

    // MARK: URLRequestConvertible

    var request: URLRequest {

        var url = URL(string: WechatRoute.baseURLString)!
        url.appendPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData

        if var urlComponents = URLComponents(url: url,
                                             resolvingAgainstBaseURL: false), !parameters.isEmpty {
            let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "")
                                    + query(parameters)
            urlComponents.percentEncodedQuery = percentEncodedQuery
            urlRequest.url = urlComponents.url
        }
        return urlRequest

    }

    /// Creates percent-escaped, URL encoded query string components
    /// from the given key-value pair using recursion.
    ///
    /// - parameter key:   The key of the query component.
    /// - parameter value: The value of the query component.
    ///
    /// - returns: The percent-escaped, URL encoded query string components.
    private func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []

        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        } else {
            components.append((escape(key), escape("\(value)")))
        }

        return components
    }

    /// Returns a percent-escaped string following RFC 3986 for a query string key or value.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that
    /// the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore,
    /// all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    ///
    /// - parameter string: The string to be percent-escaped.
    ///
    /// - returns: The percent-escaped string.
    private func escape(_ string: String) -> String {
        // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        let characters = "\(generalDelimitersToEncode)\(subDelimitersToEncode)"
        allowedCharacterSet.remove(charactersIn: characters)

        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
    }

    private func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []

        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }

        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}

class RequestController {

    private static let session = URLSession.shared

    class func request(_ route: WechatRoute,
                       completion: @escaping (_ result: [String: Any] ) -> Void ) {
        let task = session.dataTask(with: route.request) { (data, response, error) in

            guard error == nil else { return }

            guard response is HTTPURLResponse else {
                WechatManager.shared.completionHandler?(.failure(Int32(400)))
                return
            }

            guard let validData = data, !validData.isEmpty else {
                WechatManager.shared.completionHandler?(.failure(Int32(204)))
                return
            }

            let jsonObject = try? JSONSerialization.jsonObject(with: validData,
                                                               options: .allowFragments)
            guard let json = jsonObject as? [String: Any] else {
                WechatManager.shared.completionHandler?(.failure(Int32(500)))
                return
            }
            completion(json)
        }
        task.resume()
    }

}

public enum WXResult<Value, Error> {
    /// The request and all post processing operations were successful resulting in the serialization of the
    /// provided associated value.
    case success(Value)
    /// The request encountered an error resulting in a failure. The associated values are the original data
    /// provided by the server as well as the error that caused the failure.
    case failure(Error)
    
    /// Returns `true` if the result is a success, `false` otherwise.
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    /// Returns `true` if the result is a failure, `false` otherwise.
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// Returns the associated value if the result is a success, `nil` otherwise.
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// Returns the associated error value if the result is a failure, `nil` otherwise.
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

// MARK: - CustomStringConvertible

extension WXResult: CustomStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        switch self {
        case .success:
            return "SUCCESS"
        case .failure:
            return "FAILURE"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension WXResult: CustomDebugStringConvertible {
    /// The debug textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure in addition to the value or error.
    public var debugDescription: String {
        switch self {
        case .success(let value):
            return "SUCCESS: \(value)"
        case .failure(let error):
            return "FAILURE: \(error)"
        }
    }
}

import UIKit

extension UIWindow {
    /// get window
    public static var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .sorted { $0.activationState.sortPriority < $1.activationState.sortPriority }
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.windows.first { $0.isKeyWindow } }
            .first
    }
}
private extension UIScene.ActivationState {
    var sortPriority: Int {
        switch self {
        case .foregroundActive: return 1
        case .foregroundInactive: return 2
        case .background: return 3
        case .unattached: return 4
        @unknown default: return 5
        }
    }
}
extension UIViewController {
    
    /// Get the top-level UINavigationController according to the window
    public static func currentNavigationController() -> UINavigationController? {
        currentViewController()?.navigationController
    }
    
    /// Get the top-level UIViewController according to the window
    public static func currentViewController() -> UIViewController? {
        
        let vc = UIWindow.keyWindow?.rootViewController
        return getCurrentViewController(withCurrentVC: vc)
    }
    
    ///Get the top-level controller recursively according to the controller
    private static func getCurrentViewController(withCurrentVC VC : UIViewController?) -> UIViewController? {
        
        if VC == nil {
            debugPrint("🌶： Could not find top level UIViewController")
            return nil
        }
        
        if let presentVC = VC?.presentedViewController {
            //modal出来的 控制器
            return getCurrentViewController(withCurrentVC: presentVC)
            
        }
        else
        if let splitVC = VC as? UISplitViewController {
            // UISplitViewController 的跟控制器
            if splitVC.viewControllers.isEmpty {
                return VC
            }else{
                return getCurrentViewController(withCurrentVC: splitVC.viewControllers.last)
            }
        }
        else
        if let tabVC = VC as? UITabBarController {
            // tabBar 的跟控制器
            if let _ = tabVC.viewControllers {
                return getCurrentViewController(withCurrentVC: tabVC.selectedViewController)
            }else{
                return VC
            }
        }
        else
        if let naiVC = VC as? UINavigationController {
            // 控制器是 nav
            if naiVC.viewControllers.isEmpty {
                return VC
            }else{
                //return getCurrentViewController(withCurrentVC: naiVC.topViewController)
                return getCurrentViewController(withCurrentVC:naiVC.visibleViewController)
            }
        }
        else
        {
            // 返回顶控制器
            return VC
        }
    }
}
