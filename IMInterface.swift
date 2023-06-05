//
//  IMInterface.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/17.
//

import Foundation
import SwiftUI
/// 异步调用成功回调
public typealias IMSuccess = () -> Void
/// 异步调用失败回调
public typealias IMFail = (_ code: Int32, _ desc: String?) -> Void


// MARK: - IM对外提供的接口
protocol IMInterface {
    
//    MARK: - 通知分发
    func addIMListener(_ listener:IMDelegate)
    
    func removeIMListener(_ listener:IMDelegate)
    
//    MARK: - IM登录 & 退出
    /// IM登录接口
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - userSig: 用户配置
    ///   - success: 登录成功结果回调
    ///   - fail: 登录失败结果回调
    func imLogin(userId: String, userSig: String, success:@escaping IMSuccess, fail:@escaping IMFail)
    
    /// IM退出登录接口
    /// - Parameters:
    ///   - success: 退出登录结果回调
    ///   - fail: 退出登录失败回调
    func imLoginOut(success:@escaping IMSuccess, fail:@escaping IMFail)
    
    /// 查询群成员列表
    /// @note 该接口为分页查询，如果返回的结果nextSeq不为0则说明还有数据需要把上一次返回的nextSeq传入继续请求后续数据
    /// - Parameters:
    ///   - groupID: 群ID
    ///   - nextSeq: 下一个序号，如果是第一页则传0
    ///   - succ: 查询成功结果回调
    ///   - fail: 查询失败结果回调
    func getGroupMemberList(groupID:String,nextSeq:Int, succ:IMGroupMemberInfoResultSucc?, fail:IMFail?)
    /// 加入群组接口
    /// - Parameters:
    ///   - groupId: 群id
    ///   - msg: 加入群验证消息
    ///   - success: 加入群组成功回调
    ///   - fail: 加入群组失败回调
    func joinGroup(groupId: String, msg:String, success:@escaping IMSuccess, fail:@escaping IMFail)
    
    /// 退出群组接口
    /// - Parameters:
    ///   - groupId: 群id
    ///   - success: 退出群组成功回调
    ///   - fail: 退出群组失败回调
    func quitGroup(groupId: String, success:@escaping IMSuccess, fail:@escaping IMFail)
    
    /// 发送群聊文本消息
    /// - Parameters:
    ///   - groupId: 群ID
    ///   - msg: 文本消息
    ///   - success: 消息发送成功回调
    ///   - fail: 消息发送失败回调
    func sendGroupTextMessage(groupId: String, msg: String, success:@escaping IMSuccess, fail:@escaping IMFail)
    
    /// 发送单聊消息
    func sendC2CTextMessage(_ text:String, userID:String, succ:IMSuccess?, fail:IMFail?)
}


// MARK: - IM 回调
@objc public protocol IMDelegate : NSObjectProtocol {
    /// IM被踢下线
    @objc optional func onIMKickedOffline()
    
    /// 收到单聊消息
    /// - Parameters:
    ///   - msgId: 消息ID
    ///   - info: 发送者信息
    ///   - data: 消息内容
    @objc optional func onRecvP2PCustomMessage(_ msgId: String, sender info: IMUserInfo!, customData data: Data!)
    
    /// 收到群聊消息
    /// - Parameters:
    ///   - msgId: 消息ID
    ///   - groupId: 群组ID
    ///   - info: 发送者信息
    ///   - data: 消息内容
    @objc optional func onRecvGroupCustomMessage(_ msgId: String, groupId: String, sender info: IMGroupMemberInfo!, customData data: Data!)
    
    /// 收到群聊文本消息
    /// - Parameters:
    ///   - msgId: 消息ID
    ///   - groupId: 群ID
    ///   - info: 发送者信息
    ///   - text: 消息内容
    @objc optional func onRecvGroupTextMessage(_ msgId: String, groupId: String, sender info: IMGroupMemberInfo!, text: String)
    
    /// 收到群聊图片消息
    /// - Parameters:
    ///   - msgId: 消息ID
    ///   - groupId: 群ID
    ///   - info: 发送者信息
    ///   - imagePath: 图片路径
    @objc optional func onRecvGroupImageMessage(_ msgId: String, groupId: String, sender info: IMGroupMemberInfo!, imagePath: String)
    
    /// 收到群聊解散通知
    /// - Parameters:
    ///   - groupID: 群聊ID
    ///   - opUser: 解散群聊的用户
    @objc optional func onIMGroupDismissed(_ groupID: String!, opUser: IMGroupMemberInfo!)
    
    //有新成员加入群
    @objc optional func onMemberEnter(_ groupID: String!, memberList: [IMGroupMemberInfo]!)
    
    //有新成员离开群
    @objc optional func onMemberLeave(_ groupID: String!, member: IMGroupMemberInfo!)
    
    
    /// 收到服务器推送的系统消息
    @objc optional func onRecvSystemNotify(_ groupID: String, notify:IMSystemNotify,content:String?)
    
    /// IM正连接中
    @objc optional func onIMConnecting()
    
    /// IM连接成功
    @objc optional func onIMConnectSuccess()
    
    /// IM已与服务器断开连接
    /// - Parameters:
    ///   - code: 错误码
    ///   - err: 错误描述
    @objc optional func onIMConnectFailed(_ code: Int32, err: String!)
}

/// 查询群成员成功回调
public typealias IMGroupMemberInfoResultSucc = (_ nextSeq: Int64, _ list: Array<IMGroupMemberAllInfo>?) -> Void

@objc public enum memberRole: Int {
    ///未定义
    case undefined = 0
    ///群成员
    case member = 200
    ///管理员
    case admin = 300
    ///群主
    case master = 400
}

public enum Platform :String {
    ///TV
    case tv = "mitee_tv"
    ///iOS
    case iOS = "mitee_phone_ios"
    ///安卓手机
    case androidPhone = "mitee_phone_android"
    ///PC-Mac
    case mac = "mitee_pc_mac"
    ///PC-Windows
    case windows = "mitee_pc_windows"
    ///未定义
    case undefined = "undefined"
}

@objc public class IMUserInfo: NSObject {
    ///用户 ID
    public var userId: String?
    ///用户昵称
    public var nickName: String?
    ///用户头像
    public var faceURL: String?
}

@objc public class IMGroupMemberInfo: NSObject {
    ///用户 ID
    public var userId: String?
    ///mitee ID
    public var miteeUid: String?
    ///用户昵称
    public var nickName: String?
    ///用户头像
    public var faceURL: String?
    ///用户好友备注
    public var friendRemark: String?
    ///群成员名片
    public var nameCard: String?
    
    public var platform:Platform?
    ///大屏连屏码
    public var linkCode:String?
    ///大屏是否支持麦克风
    public var supportMic:String?

}

@objc public class IMGroupMemberAllInfo: IMGroupMemberInfo {
    
    ///群成员角色
    public var role:memberRole = .undefined
    ///禁言时间
    public var muteUntil:Int = 0
    ///进群时间
    public var joinTime:Int64 = 0
}


/// 系统通知
@objc public enum IMSystemNotify: Int {

    /// RTC 房间解散通知（系统通知）
    /// - 触发时机：服务端收到腾讯云的rtc 房间解散回调后，通过群通知的方式发送此消息
    case rtcRoomDismissed
    
    /// RTC 房间成员进入通知
    /// - 触发时机：服务端收到腾讯云的rtc 成员加入房间回调后，通过群通知的方式发送此消息
    case rtcMemberEntered
    
    /// RTC 房间成员离开通知
    /// - 触发时机：服务端收到腾讯云的rtc 成员退出房间回调后，通过群通知的方式发送此消息
    case rtcMemberExited
    
    /// 房间成员加入通知
    /// - 触发时机: 用户调用room/join接口后, 通知群内其他成员
    case roomMemberEntered
    
    /// 房间成员离开通知
    /// - 触发时机: 用户调用room/leave接口后, 通知群内其他成员
    case roomMemberExited
    
    /// 房间状态变化通知
    /// 触发时机:  房间状态发生变化, 开会, 停会, 房间结束
    case roomStatusChanged
    
    /// 房间信息更新通知
    /// 触发时机:  房间信息更新时 (主题, 预约时间及地点修改)
    case roomInfoUpdated
    
    /// 房间添加文件通知
    /// 触发时机:  房间有文件添加时
    case roomFileAdded
    
    /// 房间移除文件通知
    /// 触发时机:  房间有文件移除时
    case roomFileRemoved
    
    /// 大屏设备影子更新
    /// 触发时机:  房间大屏属性变化时
    case shadowUpdated
    
    /// 成员列表数据更新
    case rtcMemberInfoUpdated
    
    case none
    
    static let type = "type"
    static let flag = "SYS_NOTIFY"
    static let subKey = "subKey"
    static let content = "content"
    static let customflag = "SYS_IM_NOTIFY"
    
    public typealias RawValue = String
    public var rawValue: RawValue {
        switch self {
        case .rtcRoomDismissed:
            return "RtcRoomDismissed"
        case .rtcMemberEntered:
            return "RtcMemberEntered"
        case .rtcMemberExited:
            return "RtcMemberExited"
        case .roomMemberEntered:
            return "RoomMemberEntered"
        case .roomMemberExited:
            return "RoomMemberExited"
        case .roomStatusChanged:
            return "RoomStatusChanged"
        case .roomInfoUpdated:
            return "RoomInfoUpdated"
        case .roomFileAdded:
            return "RoomFileAdded"
        case .roomFileRemoved:
            return "RoomFileRemoved"
        case .shadowUpdated:
            return "ShadowUpdated"
        case .rtcMemberInfoUpdated:
            return "RtcMemberInfoUpdated"
        case .none:
            return "None"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "RtcRoomDismissed":
            self = .rtcRoomDismissed
        case "RtcMemberEntered":
            self = .rtcMemberEntered
        case "RtcMemberExited":
            self = .rtcMemberExited
        case "RoomMemberEntered":
            self = .roomMemberEntered
        case "RoomMemberExited":
            self = .roomMemberExited
        case "RoomStatusChanged":
            self = .roomStatusChanged
        case "RoomInfoUpdated":
            self = .roomInfoUpdated
        case "RoomFileAdded":
            self = .roomFileAdded
        case "RoomFileRemoved":
            self = .roomFileRemoved
        case "ShadowUpdated":
            self = .shadowUpdated
        case "RtcMemberInfoUpdated":
            self = .rtcMemberInfoUpdated
        default:
            self = .none
        }
    }
    
}
