//
//  File.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/9.
//

import Foundation
import RealmSwift
import SwiftyJSON

public class AccountInfo: Object,NSCopying {
    
    ///酷开token
    @objc @Persisted var ccToken:String?
    ///MiteeToken
    @objc  @Persisted var miteeToken:String?
    
    @Persisted(primaryKey: true) var uid:String?
    @Persisted var did:String?
    @Persisted var platform:Int?
    @objc @Persisted var nickname:String?
    
    @objc @Persisted var refreshToken:String?
    //用户凭证N秒后过期
    @Persisted var atExpireTime:Double?
    //刷新凭证N秒后过期
    @Persisted var rtExpireTime:Double?
    @objc @Persisted var recoveryToken:String?
    @Persisted var deleteTimestamp:Double?
    // 刷新时间，刷新时间+atExpireTime = 过期时间
    @Persisted var refreshTimestamp:Double?

    @objc @Persisted var profile:Profile?
    @Persisted var auth_info:AuthInfo?
    @Persisted var im_info:ImInfo?
    @Persisted var rtc_info:RtcInfo?
    @Persisted var meta_info:MetaInfo?
    @Persisted var login_status:Int?
    
    override init() {
        super.init()
    }
    
    func initWithData(_ data:Dictionary<String, Any>) -> AccountInfo {
        ccToken = data["ccToken"] as? String
        miteeToken = data["miteeToken"] as? String
        uid = data["uid"] as? String
        did = data["did"] as? String
        platform = data["platform"] as? Int
        nickname = data["nickname"] as? String
        
        refreshToken = data["refreshToken"] as? String;
        atExpireTime = data["atExpireTime"] as? Double;
        rtExpireTime = data["rtExpireTime"] as? Double;
        recoveryToken = data["recoveryToken"] as? String;
        deleteTimestamp = data["deleteTimestamp"] as? Double;
        refreshTimestamp = data["refreshTimestamp"] as? Double;
        
        profile = Profile();
        let pofile_ = data["profile"] as? Dictionary<String,Any>
        profile?.avatar = pofile_?["avatar"] as? String
        profile?.gender = pofile_?["gender"] as? Int
        profile?.mobile = pofile_?["mobile"] as? String
        profile?.miiteeId = pofile_?["miitee_id"] as? String
        profile?.miiteeIdExpire = pofile_?["miitee_id_expire"] as? String

        auth_info = AuthInfo();
        let auth_info_ = data["auth_info"] as? Dictionary<String,Any>
        auth_info?.coocaa_open_id = auth_info_?["coocaa_open_id"] as? String

        im_info = ImInfo();
        let im_info_ = data["im_info"] as? Dictionary<String,Any>
        im_info?.uid = im_info_?["uid"] as? String
        im_info?.usig = im_info_?["usig"] as? String

        rtc_info = RtcInfo();
        let rtc_info_ = data["rtc_info"] as? Dictionary<String,Any>
        rtc_info?.uid = rtc_info_?["uid"] as? String
        rtc_info?.usig = rtc_info_?["usig"] as? String

        meta_info = MetaInfo();
        let meta_info_ = data["meta_info"] as? Dictionary<String,Any>
        meta_info?.app_package = meta_info_?["app_package"] as? String
        meta_info?.app_version = meta_info_?["app_version"] as? String
        meta_info?.device_brand = meta_info_?["device_brand"] as? String
        meta_info?.device_model = meta_info_?["device_model"] as? String
        meta_info?.os_version = meta_info_?["os_version"] as? String
        
        meta_info?.room_id = meta_info_?["room_id"] as? String
        meta_info?.call_status = meta_info_?["call_status"] as? String
        meta_info?.microphone = meta_info_?["microphone"] as? String
        meta_info?.speaker_volume = meta_info_?["speaker_volume"] as? Int
        
        login_status = data["login_status"] as? Int
                return self
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = AccountInfo.init()
        copyObj.ccToken = self.ccToken?.copy() as? String
        copyObj.miteeToken = self.miteeToken?.copy() as? String
        copyObj.uid = self.uid?.copy() as? String
        copyObj.did = self.did?.copy() as? String
        copyObj.platform = self.platform
        copyObj.nickname = self.nickname?.copy() as? String
        copyObj.refreshToken = self.refreshToken?.copy() as? String
        copyObj.atExpireTime = self.atExpireTime
        copyObj.rtExpireTime = self.rtExpireTime
        copyObj.deleteTimestamp = self.deleteTimestamp
        copyObj.refreshTimestamp = self.refreshTimestamp
        copyObj.profile = self.profile?.copy() as? Profile
        copyObj.auth_info = self.auth_info?.copy() as? AuthInfo
        copyObj.im_info = self.im_info?.copy() as? ImInfo
        copyObj.rtc_info = self.rtc_info?.copy() as? RtcInfo
        copyObj.meta_info = self.meta_info?.copy() as? MetaInfo
        copyObj.login_status = self.login_status
        return copyObj
    }
}

public class Profile: Object,NSCopying {
    @objc @Persisted var avatar:String?
     @Persisted var gender:Int?
    @objc @Persisted var mobile:String?
    @objc @Persisted var miiteeId:String?
    @objc @Persisted var miiteeIdExpire:String?

    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = Profile.init()
        copyObj.avatar = self.avatar?.copy() as? String
        copyObj.gender = self.gender
        copyObj.mobile = self.mobile?.copy() as? String
        copyObj.miiteeId = self.miiteeId?.copy() as? String
        copyObj.miiteeIdExpire = self.miiteeIdExpire?.copy() as? String

        return copyObj
    }
}

public class AuthInfo: Object,NSCopying {
    @Persisted var coocaa_open_id:String?
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = AuthInfo.init()
        copyObj.coocaa_open_id = self.coocaa_open_id?.copy() as? String
        return copyObj
    }
}

public class ImInfo: Object,NSCopying {
    @Persisted var uid:String?
    @Persisted var usig:String?
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = ImInfo.init()
        copyObj.uid = self.uid?.copy() as? String
        copyObj.usig = self.usig?.copy() as? String
        return copyObj
    }
}

public class RtcInfo: Object,NSCopying {
    @Persisted var uid:String?
    @Persisted var usig:String?
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = RtcInfo.init()
        copyObj.uid = self.uid?.copy() as? String
        copyObj.usig = self.usig?.copy() as? String
        return copyObj
    }
}

public class MetaInfo: Object,NSCopying {
    @Persisted var app_package:String?
    @Persisted var app_version:String?
    @Persisted var device_brand:String?
    @Persisted var device_model:String?
    @Persisted var os_version:String?
    
    @Persisted var room_id:String?
    @Persisted var call_status:String?
    @Persisted var microphone:String?
    @Persisted var speaker_volume:Int?
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copyObj = MetaInfo.init()
        copyObj.app_package = self.app_package?.copy() as? String
        copyObj.app_version = self.app_version?.copy() as? String
        copyObj.device_brand = self.device_brand?.copy() as? String
        copyObj.device_model = self.device_model?.copy() as? String
        copyObj.os_version = self.os_version?.copy() as? String
        
        copyObj.room_id = self.room_id?.copy() as? String
        copyObj.call_status = self.call_status?.copy() as? String
        copyObj.microphone = self.microphone?.copy() as? String
        copyObj.speaker_volume = self.speaker_volume
        return copyObj
    }
}
