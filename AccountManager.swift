//
//  AccountManager.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/5.
//

import Foundation

/// 账号登录成功
public let AccountManagerLoginNotification = "AccountManagerLoginNotification"
/// 账号登录失败
public let AccountManagerLogoutNotification = "AccountManagerLogoutNotification"

/// 账号信息变更
public let AccountManagerUpdateUserInfoNotification = "AccountManagerUpdateUserInfoNotification"

@objc public class AccountManager: NSObject{
    
    /// 单例初始化接口
    @objc public static let shared = AccountManager()
    
    /// 本地存储实例
    var storage:StorageInterface?
    
    /// 用户是否已登录
    @objc public var login:Bool {
        get {
            return self.accountInfo?.miteeToken != nil
        }
    }
    
    /// 用户信息
    @objc public var accountInfo:AccountInfo?
    
    /// 单例初始化接口
    private let api = AccountApi()
    
    //MARK:- lifecycle

    private override init() {
        super.init()
    }
    
    @objc public override func copy() -> Any {
        return self
    }
    
    @objc public override func mutableCopy() -> Any {
        return self
    }
    
    private func saveUserInfo(info:AccountInfo) {
        CCLog("did save accountInfo:\(String(describing: info))",tag:"Account")

        //本地缓存
        let objects = RealmStorage.objects(AccountInfo.self)
        if objects?.count ?? 0 > 0 {
            storage?.deleteObjects(objects!)
        }
        
        storage?.addObject(info)
    }
    
    
    /// 加载缓存账号
    func loadCacheInfo() {
        let info = self.storage?.selectObject(AccountInfo.self)
        accountInfo = (info as? AccountInfo)?.copy() as? AccountInfo
        CCLog("Select local user info\n\(String(describing: info))")
        
        
        
        if (self.shouldRefreshToken())  {
            self.refreshToken()
        } else {
            NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
            /// 刷新用户信息
            self.refreshUserInfo()
        }
    }
    
    /// 刷新用户信息
    func refreshUserInfo() {
        guard let info = self.accountInfo else { return }
        guard let mToken = info.miteeToken else { return }
        CCLog("requestMiteeUserInfo: \(String(describing: mToken))",tag:"Account")
        self.requestMiteeUserInfo(token: mToken) { responseObj in
            CCLog("requestMiteeUserInfo \(String(describing: responseObj))",tag:"Account")
            NotificationCenter.default.post(name: NSNotification.Name(AccountManagerUpdateUserInfoNotification), object: nil)
        } fail: { code, desc in
            CCLog("requestMiteeUserInfo:\(code) \(String(describing: desc))",tag:"Account")
            if code == 403001 {
//                self.logout()
            }
        }
    }
    
    func refreshToken() {
        CCLog("refreshToken...")
        guard let mToken = self.accountInfo?.miteeToken else { return }
        guard let rToken = self.accountInfo?.refreshToken else { return }
        api.refreshMiteeToken(token: mToken, refreshToken: rToken) { responseObj in
            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                
                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("refreshToken successful!")
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
            } else {
                CCLog("refreshToken failed!")
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
            }
        } fail: { code, desc in
            CCLog("refreshToken failed!")
            NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
        }
    }
    
    
    @objc public func shouldRefreshToken() -> Bool {
        guard let info = self.accountInfo else { return false}
        let refreshTimestamp = info.refreshTimestamp ?? 0
        let refreshDate = Date.init(timeIntervalSince1970: refreshTimestamp)
        let timeOffset = Date().timeIntervalSince(refreshDate)
        let defualtTime = self.accountInfo?.atExpireTime ?? 7*24*60*60
        return timeOffset > (defualtTime - 24*60*60)
    }
    
    
    /// 退出账号
    @objc func logout() {
        if self.accountInfo != nil {
            self.storage?.deleteObject(AccountInfo.self)
        }
        self.accountInfo = nil;
        NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLogoutNotification), object: nil)
    }
    
}

extension AccountManager {
    
    /// 通过验证码登录
    /// - Parameters:
    ///   - captch: 短信验证码
    ///   - mobile: 手机号
    ///   - success: 成功回调
    ///   - fail: 失败回调
    @objc public func loginByCaptcha(_ captcha:String!, mobile:String, success:AccountSuccess?, fail:AccountFail?) {
        api.loginByCaptcha(captcha, mobile: mobile) { responseObj in

            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
                
                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("login Mitee successful!")
                success?(info)
            } else {
                CCLog("login Mitee failed!")
                fail?(1002,"login Mitee failed!")
            }
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    /// 通过密码登录接口
    /// - Parameters:
    ///   - account: 登录账号
    ///   - password: 登录密码/验证码
    ///   - success: 登录成功回调
    ///   - fail: 登录失败回调
    @objc public func loginByPassword(_ password: String, account: String, success:AccountSuccess?, fail:AccountFail?) {
        api.loginByPassword(password, account: account) { responseObj in

            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)

                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("login Mitee successful!")
                success?(info)
            } else {
                CCLog("login Mitee failed!")
                fail?(1002,"login Mitee failed!")
            }
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    @objc public func loginByRecoveryToken(_ token:String!, success:AccountSuccess?, fail:AccountFail?) {
        api.miteeLogin(token: token, captcha: "", type: 9) { responseObj in
            
            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
                
                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("login Mitee successful!")
                success?(info)
            } else {
                CCLog("login Mitee failed!")
                fail?(1002,"login Mitee failed!")
            }
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    @objc public func quicklyloginByClToken(_ token:String!, success:AccountSuccess?, fail:AccountFail?) {
        api.miteeLogin(token: token, captcha: "", type: 10) { responseObj in
            
            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
                
                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("login Mitee successful!")
                success?(info)
            } else {
                CCLog("login Mitee failed!")
                fail?(1002,"login Mitee failed!")
            }
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    @objc public func loginByUDID(_ token:String!, success:AccountSuccess?, fail:AccountFail?) {
        api.miteeLogin(token: token, captcha: "", type: 2) { responseObj in
            
            let tokenInfo = responseObj as? Dictionary<String,Any>
            if tokenInfo != nil {
                let info = AccountInfo().initWithData(tokenInfo ?? [:])
                self.accountInfo = info
                NotificationCenter.default.post(name: NSNotification.Name(AccountManagerLoginNotification), object: nil)
                
                self.saveUserInfo(info: info.copy() as! AccountInfo)
                CCLog("login Mitee successful!")
                success?(info)
            } else {
                CCLog("login Mitee failed!")
                fail?(1002,"login Mitee failed!")
            }
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    public func miiteePadLogin(success:AccountSuccess?, fail:AccountFail?) {
        let uuid = miteeUUID()

        api.registerDevice(udid: uuid) { responseObj in
            let tokenInfo = responseObj as? Dictionary<String,Any>
            let deviceId = tokenInfo?["device_id"] as? String ?? ""
            let token = miiteePadToken(deviceId: deviceId)
            CCLog("device_id:\(deviceId)\n authToken:\(token)")
            self.loginByUDID(token) { responseObj in
                success?(responseObj)
            } fail: { code, desc in
                fail?(code, desc)
            }
        } fail: { code, desc in
            fail?(code, desc)
        }

        

    }
    
    /// 获取登录验证码
    /// - Parameters:
    ///   - mobile: 手机号
    ///   - success: 登录成功回调
    ///   - fail: 登录失败回调
    @objc public func requestMobileCatch(mobile: String, success:@escaping AccountSuccess, fail:@escaping AccountFail) {
        api.requestMobileCaptcha(mobile: mobile, success: success, fail: fail)
    }
    
    /// 获取用户信息
    /// - Parameters:
    ///   - token: token
    ///   - success: 登录成功回调
    ///   - fail: 登录失败回调
    @objc public func requestUserInfo(token: String, success:@escaping AccountSuccess, fail:@escaping AccountFail) {
        api.requestUserInfo(token: token, success: success, fail: fail)
    }
    
    /// 获取Mitee用户信息
    /// - Parameters:
    ///   - token: Mitee token
    ///   - success: 登录成功回调
    ///   - fail: 登录失败回调
    func requestMiteeUserInfo(token: String, success:AccountSuccess?, fail:AccountFail?) {
        //兼容旧版本
        self.api.requestMiteeUserInfo(token: token) { responseObj in
            guard var tokenInfo = responseObj as? Dictionary<String,Any> else {
                fail?(1001 , "request failed")
                return
            }
            
            tokenInfo["miteeToken"] = token;
            tokenInfo["ccToken"] = self.accountInfo?.ccToken;
            tokenInfo["refreshToken"] = self.accountInfo?.refreshToken;
            tokenInfo["atExpireTime"] = self.accountInfo?.atExpireTime;
            tokenInfo["rtExpireTime"] = self.accountInfo?.rtExpireTime;
            tokenInfo["refreshTimestamp"] = self.accountInfo?.refreshTimestamp;

            let info = AccountInfo().initWithData(tokenInfo)
            self.accountInfo = info
            
            self.saveUserInfo(info: info.copy() as! AccountInfo)
            CCLog("login Mitee successful!")
            success?(info)
            
        } fail: { code, message in
            fail?(code,message)
        }
    }
    
    
    /// 更新用户头像
    /// - Parameter image: 用户头像
    func updateUserAvatar(image:UIImage, success:AccountSuccess?, fail:AccountFail?) {
        let api = AccountApi()
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        api.updateMiteeUserAvatar(token: AccountManager.shared.accountInfo?.miteeToken ?? "", data: imageData, extention: "jpg") { responseObj in
            CCLog("updateMiteeUserAvatar successful")
            guard let url = responseObj as? String else { return }
            self.accountInfo?.profile?.avatar = url
            self.saveUserInfo(info: self.accountInfo?.copy() as! AccountInfo)
            success?(responseObj)
            
            NotificationCenter.default.post(name: NSNotification.Name(AccountManagerUpdateUserInfoNotification), object: nil)
        } fail: { code, desc in
            CCLogError("updateMiteeUserAvatar failed, code(\(code)) msg:\(String(describing: desc))")
            fail?(code, desc)
        }
    }
    
    func updateNikeName(name:String, success:AccountSuccess?, fail:AccountFail?) {
        
        let api = AccountApi()
        api.updateMiteeUserInfo(token: AccountManager.shared.accountInfo?.miteeToken ?? "", nikeName: name) { responseObj in
            CCLog("updateMiteeUserInfo sucess")
            self.accountInfo?.nickname = name
            self.saveUserInfo(info: self.accountInfo?.copy() as! AccountInfo)
            success?(responseObj)
            
            NotificationCenter.default.post(name: NSNotification.Name(AccountManagerUpdateUserInfoNotification), object: nil)
        } fail: { code, desc in
            CCLogError("updateMiteeUserInfo failed,code(\(code), msg:\(String(describing: desc))")
            fail?(code, desc)
        }
    }
}
