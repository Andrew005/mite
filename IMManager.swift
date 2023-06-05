//
//  CCIMManager.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/4.
//

import Foundation
import ImSDK_Plus
import CoreMIDI
import SwiftyJSON


/// IM登录状态
public enum IMLoginStatus : Int64{
    case Logined = 1
    case Logining = 2
    case LogOut = 3
}
 

@objc public class IMManager: NSObject{
    
    /// IM事件回调
    private var delegates = NSMutableSet()
    /// 登录事件回调
    private var loginCallback = NSMutableSet()
    
    /// 单例初始化接口
    @objc public static let shared = IMManager()
    
    /// 当前的登录状态，如果登录失败，后台会自动重新登录
    public var loginStatus:IMLoginStatus = .LogOut {
        didSet {
            CCLog("loginStatusChanged:\(loginStatus)",tag: TAG_IM)
        }
    }
    /// 用于自动登录
    private var autoReLogin:Bool = true
    
    /// 信令接收者
    var singlinger:SigalingListener?
    
    
    private lazy var imManager: V2TIMManager = {
        let instance: V2TIMManager = V2TIMManager.sharedInstance()
        return instance;
    }()
    
    //MARK:- lifecycle

    private override init() {
        //启动IMSdk
    }
    
    @objc public override func copy() -> Any {
        return self
    }
    
    @objc public override func mutableCopy() -> Any {
        return self
    }
    
    
    /// 初始化SDK
    /// - Returns: 初始化IM结果，成功访问true，失败返回false
    func initSDK() -> Bool {
        self.imManager.unInitSDK()
        let config = V2TIMSDKConfig()
        config.logLevel = V2TIMLogLevel.LOG_NONE
        let result = self.imManager.initSDK(Int32(Domain.type == .Release ? MiteeConfig.TIMAppID : MiteeConfig.TIMAppIDBeta)!, config: config)
        self.imManager.addSimpleMsgListener(listener: self)
        self.imManager.addSignalingListener(listener: self)
        self.imManager.addGroupListener(listener: self)
        self.imManager.addConversationListener(listener: self)
        self.imManager.addAdvancedMsgListener(listener: self)
        self.imManager.add(self)
        return result
    }
    
    ///更新个人信息到IM服务器
    func updateUserInfo() {
        let imInfo = V2TIMUserFullInfo()
        imInfo.nickName = AccountManager.shared.accountInfo?.nickname
        imInfo.faceURL = AccountManager.shared.accountInfo?.profile?.avatar
        imInfo.gender = V2TIMGender(rawValue: AccountManager.shared.accountInfo?.profile?.gender ?? 0) ?? V2TIMGender.GENDER_UNKNOWN
        
        let appInfo = ["type":Platform.iOS.rawValue,"miteeUid":AccountManager.shared.accountInfo?.uid ?? ""]
        let data = try? JSONSerialization.data(withJSONObject: appInfo, options: [])
        guard data != nil else { return}
        let customeInfo = ["App":data!]
        imInfo.customInfo = customeInfo
        
        imManager.setSelfInfo(imInfo) {
            CCLog("setSelfInfo successful!",tag:TAG_IM)
            
        } fail: { code, message in
            CCLogError("setSelfInfo failed!! code=\(code),message=\(String(describing: message))",tag:TAG_IM)
        }
    }
}

extension IMManager:IMInterface {
//    MARK: - 通知分发(临时处理)
    func addIMListener(_ listener:IMDelegate){
        self.delegates.add(listener)
    }
    
    func removeIMListener(_ listener:IMDelegate){
        self.delegates.remove(listener)
    }
    
//    MARK: - IM登录 & 退出
    /// IM登录接口
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - userSig: 用户配置
    ///   - success: 登录成功结果回调
    ///   - fail: 登录失败结果回调
    func imLogin(userId: String, userSig: String, success:@escaping IMSuccess, fail:@escaping IMFail) {
        self.autoReLogin = true
        self.login(userId: userId, userSig: userSig, success: success, fail: fail)
    }
    
    func login(userId: String, userSig: String, success:@escaping IMSuccess, fail:@escaping IMFail) {
        let callback = (succ:success,fail:fail)
        loginCallback.add(callback)
        if imManager.getLoginStatus() == .STATUS_LOGOUT {
            self.loginStatus = .Logining
            imManager.login(userId, userSig: userSig) {
                self.loginStatus = .Logined
                //更新个人信息
                self.updateUserInfo()
                
                for call in self.loginCallback {
                    guard let value = call as? (succ:IMSuccess,fail:IMFail) else { return }
                    value.succ()
                }
                self.loginCallback.removeAllObjects()
            } fail: { failCode, desc in
                self.loginStatus = .LogOut
                
                for call in self.loginCallback {
                    guard let value = call as? (succ:IMSuccess,fail:IMFail) else { return }
                    value.fail(Int32(Int(failCode)), desc)
                }
                self.loginCallback.removeAllObjects()
                
                if self.autoReLogin {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.imLogin(userId: userId, userSig: userSig) {
                            
                        } fail: { code, desc in
                            
                        }
                    }
                }
                
            }
        }
    }
    
    /// IM退出登录接口
    /// - Parameters:
    ///   - success: 退出登录结果回调
    ///   - fail: 退出登录失败回调
    func imLoginOut(success:@escaping IMSuccess, fail:@escaping IMFail) {
        self.autoReLogin = false
        imManager.logout {
            self.loginStatus = .LogOut
            success()
        } fail: { failCode, desc in
            fail(Int32(Int(failCode)), desc)
        }
    }
    
    private func checkIMLoginStatus(success:@escaping IMSuccess, fail:@escaping IMFail) {
        if loginStatus == .Logined {
            success()
        } else {
            let userId = AccountManager.shared.accountInfo?.im_info?.uid ?? ""
            let userSign = AccountManager.shared.accountInfo?.im_info?.usig ?? ""
            self.login(userId: userId, userSig: userSign) {
                success()
            } fail: { code, desc in
                fail(Int32(Int(code)),desc)
            }
        }
    }
    
//    MARK: 群组
    /// 查询群成员列表
    /// @note 该接口为分页查询，如果返回的结果nextSeq不为0则说明还有数据需要把上一次返回的nextSeq传入继续请求后续数据
    /// - Parameters:
    ///   - groupID: 群ID
    ///   - nextSeq: 下一个序号，如果是第一页则传0
    ///   - succ: 查询成功结果回调
    ///   - fail: 查询失败结果回调
    public func getGroupMemberList(groupID:String,nextSeq:Int, succ:IMGroupMemberInfoResultSucc?, fail:IMFail?) {
//        self.checkIMLoginStatus {
//            self.imManager.getGroupMemberList(groupID, filter: V2TIMGroupMemberFilter.GROUP_MEMBER_FILTER_ALL, nextSeq:UInt64(nextSeq)) { code, list in
//                CCLog("getGroupMemberList \(String(describing: list))",tag:TAG_IM)
//                
//                guard list != nil else {
//                    succ?(Int64(code),nil)
//                    return
//                }
//                var memberList = Array<IMGroupMemberAllInfo>()
//                let tempList = list?.map({$0.userID})
//                guard let tList = tempList as? [String] else {
//                    return
//                }
//                self.imManager.getUsersInfo(tList) { infoList in
//                    for index in 0...list!.count-1 {
//                        let item = list![index]
//                        for userInfo in infoList! {
//                            if userInfo.userID == item.userID {
//                                let appData = userInfo.customInfo["App"]
//                                let appInfo = try? JSON(data: appData ?? Data())
//                                let type = appInfo?["type"].stringValue
//                                let miteeUid = appInfo?["miteeUid"].stringValue
//                                
//                                let memberAllInfo = IMGroupMemberAllInfo()
//                                memberAllInfo.userId = item.userID ?? ""
//                                memberAllInfo.miteeUid = miteeUid ?? ""
//                                memberAllInfo.nickName = item.nickName ?? ""
//                                memberAllInfo.faceURL = item.faceURL ?? ""
//                                memberAllInfo.friendRemark = item.friendRemark ?? ""
//                                memberAllInfo.nameCard = item.nameCard ?? ""
//                                memberAllInfo.role = memberRole(rawValue: item.role.rawValue) ?? .undefined
//                                memberAllInfo.muteUntil = Int(item.muteUntil)
//                                memberAllInfo.joinTime = Int64(item.joinTime)
//                                memberAllInfo.linkCode = appInfo?["linkCode"].stringValue
//                                memberAllInfo.supportMic = appInfo?["supportMic"].stringValue
//                                
//                                if type != nil {
//                                    let platform = Platform.init(rawValue: type ?? Platform.undefined.rawValue)
//                                    memberAllInfo.platform = platform
//                                } else {
//                                    memberAllInfo.platform = Platform.undefined
//                                }
//                                
//                                memberList.append(memberAllInfo)
//                                break
//                            }
//                        }
//                        
//                    }
//                    
//                    succ?(Int64(code),memberList)
//                } fail: { code, message in
//                    CCLogError("getGroupMemberList!! code=\(code),message=\(String(describing: message))",tag:TAG_IM)
//                    fail?(code,message)
//                }
//                
//     
//            } fail: { code, message in
//                
//                CCLogError("getGroupMemberList!! code=\(code),message=\(String(describing: message))",tag:TAG_IM)
//                fail?(code,message)
//            }
//        } fail: { code, desc in
//            fail?(code,desc)
//        }
    }
    /// 加入群组接口
    /// - Parameters:
    ///   - groupId: 群id
    ///   - msg: 加入群验证消息
    ///   - success: 加入群组成功回调
    ///   - fail: 加入群组失败回调
    @objc public func joinGroup(groupId: String, msg:String, success:@escaping IMSuccess, fail:@escaping IMFail) {
        self.checkIMLoginStatus {
            V2TIMManager.sharedInstance().joinGroup(groupId, msg: msg) {
                success()
            } fail: { errCode, desc in
                fail(Int32(Int(errCode)),desc)
            }
        } fail: { code, desc in
            fail(Int32(Int(code)),desc)
        }
    }
    
    /// 退出群组接口
    /// - Parameters:
    ///   - groupId: 群id
    ///   - success: 退出群组成功回调
    ///   - fail: 退出群组失败回调
    @objc public func quitGroup(groupId: String, success:@escaping IMSuccess, fail:@escaping IMFail) {
        self.checkIMLoginStatus {
            V2TIMManager.sharedInstance().quitGroup(groupId) {
                success()
            } fail: { errCode, desc in
                fail(errCode,desc)
            }
        } fail: { code, desc in
            fail(Int32(Int(code)),desc)
        }
    }
    
//    MARK: 消息发送
    /// 发送群聊文本消息
    /// - Parameters:
    ///   - groupId: 群ID
    ///   - msg: 文本消息
    ///   - success: 消息发送成功回调
    ///   - fail: 消息发送失败回调
    @objc func sendGroupTextMessage(groupId: String, msg: String, success:@escaping IMSuccess, fail:@escaping IMFail) {
        self.checkIMLoginStatus {
            self.imManager.sendGroupTextMessage(msg, to: groupId, priority: .PRIORITY_HIGH) {
                CCLog("sendGroupTextMessage success:\(msg)",tag: TAG_IM)
                success()
            } fail: { errCode, desc in
                fail(errCode, desc)
            }
        } fail: { code, desc in
            fail(Int32(Int(code)),desc)
        }
        
    }
    
    /// 发送单聊消息
    func sendC2CTextMessage(_ text:String, userID:String, succ:IMSuccess?, fail:IMFail?) {
        self.checkIMLoginStatus {
            self.imManager.sendC2CTextMessage(text, to: userID, succ: succ, fail: fail)
        } fail: { code, desc in
            fail?(code,desc)
        }
    }
    
    /**
     *  5.2 获取群组历史消息
     *
     *  @param count 拉取消息的个数，不宜太多，会影响消息拉取的速度，这里建议一次拉取 20 个
     *  @param lastMsg 获取消息的起始消息，如果传 nil，起始消息为会话的最新消息
     *
     *  @note 请注意：
     *  - 如果 SDK 检测到没有网络，默认会直接返回本地数据
     *  - 只有会议群（Meeting）才能拉取到进群前的历史消息，直播群（AVChatRoom）消息不存漫游和本地数据库，调用这个接口无效
     *
     */
    func getGroupHistory(_ groupId:String, count:Int32, lastMsg:V2TIMMessage?, succ:V2TIMMessageListSucc?, fail:IMFail?) {
        self.checkIMLoginStatus {
            self.imManager.getGroupHistoryMessageList(groupId, count: count, lastMsg: nil, succ:succ, fail:fail)
        } fail: { code, desc in
            fail?(Int32(Int(code)),desc)
        }
    }
    
    
    /// 获取所有会话的未读消息总数
    func getTotalUnreadMessageCount(_ succes:V2TIMTotalUnreadMessageCountSucc?, fail:V2TIMFail?) {
        self.imManager.getTotalUnreadMessageCount { count in
            succes?(count)
        } fail: { code, desc in
            fail?(code,desc)
        }
    }
}


//MARK: - 消息回调
extension IMManager: V2TIMSDKListener {
    
    //本端被踢下线
    public func onKickedOffline() {
        for delegate in self.delegates {
            (delegate as AnyObject).onIMKickedOffline?()
        }
    }
    
    public func onConnecting() {
        //
        CCLog("IM正在连接中...",tag: TAG_IM)
        for delegate in self.delegates {
            (delegate as AnyObject).onIMConnecting?()
        }
    }
    
    public func onConnectSuccess() {
        CCLog("IM已连接成功",tag: TAG_IM)
        
        for delegate in self.delegates {
            (delegate as AnyObject).onIMConnectSuccess?()
        }
    }
    
    public func onConnectFailed(_ code: Int32, err: String!) {
        CCLog("IM已与服务器断开连接",tag: TAG_IM)
        for delegate in self.delegates {
            (delegate as AnyObject).onIMConnectFailed?(code, err: err)
        }
    }
    
}

extension IMManager: V2TIMSimpleMsgListener {
    
    public func onRecvC2CTextMessage(_ msgID: String!, sender info: V2TIMUserInfo!, text: String!) {
        CCLog("onRecvC2CTextMessage:\(String(describing: text)) from:\(String(describing: info))",tag: TAG_IM)
    }
    
    //收到单聊自定义消息
    public func onRecvC2CCustomMessage(_ msgID: String!, sender info: V2TIMUserInfo!, customData data: Data!) {
        let userInfo: IMUserInfo = IMUserInfo()
        userInfo.userId = info.userID ?? ""
        userInfo.nickName = info.nickName ?? ""
        userInfo.faceURL = info.faceURL ?? ""
        for delegate in self.delegates {
            (delegate as AnyObject).onRecvP2PCustomMessage?(msgID, sender: userInfo, customData: data)
        }
        let msg = String(data: data, encoding: .utf8)
        CCLog("onRecvC2CCustomMessage:\(msg ?? "") from:\(String(describing: info))",tag: TAG_IM)
    }
    
    //收到群自定义消息
    public func onRecvGroupCustomMessage(_ msgID: String!, groupID: String!, sender info: V2TIMGroupMemberInfo!, customData data: Data!) {
        let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
        memberInfo.userId = info.userID
        memberInfo.nickName = info.nickName
        memberInfo.faceURL = info.faceURL
        memberInfo.friendRemark = info.friendRemark
        memberInfo.nameCard = info.nameCard
        for delegate in self.delegates {
            (delegate as AnyObject).onRecvGroupCustomMessage?(msgID, groupId: groupID, sender: memberInfo, customData: data)
        }
        
//        let msg = String(data: data, encoding: .utf8)
//        CCLog("onRecvGroupCustomMessage:\(msg ?? "") from:\(String(describing: info))",tag: TAG_IM)
    }
    
    /// 收到群聊文本消息
    /// - Parameters:
    ///   - msgID: 消息ID
    ///   - groupID: 群ID
    ///   - info: 发送者信息
    ///   - text: 消息内容
    public func onRecvGroupTextMessage(_ msgID: String!, groupID: String!, sender info: V2TIMGroupMemberInfo!, text: String!) {
        let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
        memberInfo.userId = info.userID ?? ""
        memberInfo.nickName = info.nickName ?? ""
        memberInfo.faceURL = info.faceURL ?? ""
        memberInfo.friendRemark = info.friendRemark ?? ""
        memberInfo.nameCard = info.nameCard ?? ""
        
        for delegate in self.delegates {
            (delegate as AnyObject).onRecvGroupTextMessage?(msgID, groupId: groupID, sender: memberInfo, text: text)
        }
        
        CCLog("onRecvGroupTextMessage:\(text ?? "") from:\(String(describing: info))",tag: TAG_IM)
    }
}

extension IMManager: V2TIMGroupListener {
    
    //有新的群被创建
    public func onGroupCreated(_ groupID: String!) {
        CCLog("有新的群：\(String(describing: groupID))被创建",tag: TAG_IM)
    }
    
    //有新成员加入群
    public func onMemberEnter(_ groupID: String!, memberList: [V2TIMGroupMemberInfo]!) {
        
        var list:Array = Array<IMGroupMemberInfo>()
        
        for item in memberList {
            let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
            memberInfo.userId = item.userID ?? ""
            memberInfo.nickName = item.nickName ?? ""
            memberInfo.faceURL = item.faceURL ?? ""
            memberInfo.friendRemark = item.friendRemark ?? ""
            memberInfo.nameCard = item.nameCard ?? ""
            list.append(memberInfo)
        }
        
        for delegate in self.delegates {
            (delegate as AnyObject).onMemberEnter?(groupID, memberList: list)
        }
    }
    
    //有新成员离开群
    public func onMemberLeave(_ groupID: String!, member: V2TIMGroupMemberInfo!) {
        let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
        memberInfo.userId = member.userID ?? ""
        memberInfo.nickName = member.nickName ?? ""
        memberInfo.faceURL = member.faceURL ?? ""
        memberInfo.friendRemark = member.friendRemark ?? ""
        memberInfo.nameCard = member.nameCard ?? ""
        
        for delegate in self.delegates {
            (delegate as AnyObject).onMemberLeave?(groupID, member: memberInfo)
        }
    }
    
    //加入的群被解散
    public func onGroupDismissed(_ groupID: String!, opUser: V2TIMGroupMemberInfo!) {
        
        let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
        memberInfo.userId = opUser.userID ?? ""
        memberInfo.nickName = opUser.nickName ?? ""
        memberInfo.faceURL = opUser.faceURL ?? ""
        memberInfo.friendRemark = opUser.friendRemark ?? ""
        memberInfo.nameCard = opUser.nameCard ?? ""
        
        for delegate in self.delegates {
            (delegate as AnyObject).onIMGroupDismissed?(groupID, opUser: memberInfo)
        }
    }
    
    //加入的群被回收
    public func onGroupRecycled(_ groupID: String!, opUser: V2TIMGroupMemberInfo!) {
        CCLog("加入的群:\(String(describing: groupID))已被回收",tag: TAG_IM)
    }
    
    /// 收到 RESTAPI 下发的自定义系统消息
    public func onReceiveRESTCustomData(_ groupID: String!, data: Data!) {
        let msg = String(data: data, encoding: .utf8)
        let msgObj = msg?.dictionaryValue()
        CCLog("onReceiveRESTCustomData:\(String(describing: msgObj)) from:\(String(describing: groupID))",tag: TAG_IM)
        var flagValue = msgObj?[IMSystemNotify.type]
        if flagValue == nil {
            flagValue = msgObj?["Type"]
        }
        guard let flag = flagValue as? String else { return }
        if flag == IMSystemNotify.flag {
            var subKey = msgObj?[IMSystemNotify.subKey]
            if subKey == nil {
                subKey = msgObj?["SubKey"]
            }
            guard let rawValue = subKey as? String else { return }
            let content = msgObj?[IMSystemNotify.content] as? String
            let notify = IMSystemNotify.init(rawValue: rawValue) ?? .none
            
            for delegate in self.delegates {
                (delegate as AnyObject).onRecvSystemNotify?(groupID, notify: notify, content: content)
            }
        }
        

    }
}

extension IMManager: V2TIMConversationListener {
    //有新的会话
    public func onNewConversation(_ conversationList: [V2TIMConversation]!) {
        
    }
    
    //会话信息发生变化
    public func onConversationChanged(_ conversationList: [V2TIMConversation]!) {
        
    }
}

//MARK: 信令
extension IMManager: V2TIMSignalingListener{
    /// 收到邀请的回调
    public func onReceiveNewInvitation(_ inviteID: String!, inviter: String!, groupID: String!, inviteeList: [String]!, data: String?) {
        //转发信令
        self.singlinger?.onReceiveSigaling(inviteID, signaler: inviter, groupID: groupID, receiverList: inviteeList, data: data)

        //其他业务
    }
    
    /// 被邀请者接受邀请
    public func onInviteeAccepted(_ inviteID: String!, invitee: String!, data: String?) {
        //转发信令
        self.singlinger?.onSigalingReply(inviteID, receiver: invitee, data: data)

        //其他业务
    }
    
    /// 被邀请者拒绝邀请
    public func onInviteeRejected(_ inviteID: String!, invitee: String!, data: String?) {
        
    }
    
    /// 邀请被取消
    public func onInvitationCancelled(_ inviteID: String!, inviter: String!, data: String?) {
        //转发信令
        self.singlinger?.onSigalingCancelled(inviteID, signaler: inviter, data: data)

        //其他业务
    }
    
    /// 邀请超时
    public func onInvitationTimeout(_ inviteID: String!, inviteeList: [String]!) {
        //转发信令
        self.singlinger?.onSigalingTimeout(inviteID, receiverList: inviteeList)

        //其他业务
    }
}

extension IMManager: V2TIMAdvancedMsgListener {
    /// 收到新消息
    public func onRecvNewMessage(_ msg: V2TIMMessage!) {
        
        switch msg.elemType {
        case V2TIMElemType.ELEM_TYPE_IMAGE:
            CCLog("收到新图片消息",tag: TAG_IM)
            
            let memberInfo: IMGroupMemberInfo = IMGroupMemberInfo()
            memberInfo.userId = msg.userID ?? ""
            memberInfo.nickName = msg.nickName ?? ""
            memberInfo.faceURL = msg.faceURL ?? ""
            memberInfo.friendRemark = msg.friendRemark ?? ""
            memberInfo.nameCard = msg.nameCard ?? ""
            
            let imageList = msg.imageElem.imageList
            var imageUrl = ""
            for item in imageList! {
                imageUrl = item.url
                break
            }
            
            for delegate in self.delegates {
                (delegate as AnyObject).onRecvGroupImageMessage?(msg.msgID, groupId: msg.groupID, sender: memberInfo, imagePath: imageUrl)
            }
            
//            CCLog("onRecvGroupImageMessage",tag: TAG_IM)
            
        default:
            CCLog("收到未知类型消息:\(msg.elemType)",tag: TAG_IM)
        }
    }
}

extension IMManager: SignalingInterface {
    /// 发送信令
    /// - Parameters:
    ///   - toUserId: 目标的用户ID
    ///   - content: 用户自定义数据
    ///   - timeout: 超时时间，单位秒，默认5秒，小于等于0会取默认时间
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    /// - Returns: 信令ID，如果失败返回，nil
    func send(_ toUserId: String!, content: String!, timeout: Int32,succ:SignalingSucc?,fail: SignalingFail?) -> String? {
        return self.imManager.invite(toUserId, data: content, onlineUserOnly: true, offlinePushInfo: V2TIMOfflinePushInfo(), timeout: timeout, succ: succ, fail: fail)
    }
    
    /// 群发信令
    /// - Parameters:
    ///   - groupID: 群ID
    ///   - receiveList: 接受者列表
    ///   - content: 用户自定义数据
    ///   - timeout: 超时时间，单位秒，默认5秒，小于等于0会取默认时间
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    /// - Returns: 信令ID，如果失败返回，nil
    func sendInGroup(_ groupID: String!, receiveList: [String]!, content: String!, timeout: Int32,succ:SignalingSucc?,fail:SignalingFail?) -> String? {
//        let customData = [
//            "type": "SYS_IM_NOTIFY",
//            "key": "IMNotify",
//            "subKey": "ShareDocment",
//            "content": "{\"fullText\":\"王铁柱 共享了“产品项目排期.pptx”\"}"
//        ]
//        let jsonString = customData.jsonStringValue() ?? "Hello"
//        self.imManager.sendGroupCustomMessage(jsonString.data(using: .utf8), to: groupID, priority: .PRIORITY_HIGH) {
//            CCLog("sendGroupCustomMessage successful")
//        } fail: { code, desc in
//            CCLog("sendGroupCustomMessage failed")
//        }
        return self.imManager.invite(inGroup: groupID, inviteeList: receiveList, data: content, onlineUserOnly: true, timeout: timeout, succ: succ, fail: fail)
    }
    
    /// 取消信令
    /// - Parameters:
    ///   - signalingId: 信令ID
    ///   - content: 用户自定义数据
    func cancel(_ signalingId: String!, content: String!,succ:SignalingSucc?,fail:SignalingFail?) -> Void {
        self.imManager.cancel(signalingId, data: content, succ: succ, fail: fail)
    }
    
    /// 回复信令
    /// - Parameters:
    ///   - receiveID:待回复的信令ID
    ///   - content: 用户自定义数据
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    func reply(_ receiveID:String!, content:String!, succ:SignalingSucc?,fail:SignalingFail?) -> Void {
        self.imManager.accept(receiveID, data: content, succ: succ, fail: fail)
//        self.imManager.cancel(receiveID, data: content, succ: succ, fail: fail)
    }
}


