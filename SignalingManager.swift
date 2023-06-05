//
//  SignalingManager.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/6.
//

import Foundation
import SwiftyJSON

/// 信令标识，用于识别是否是信令
private let SignalFlag = "SIGNALING"
private let SignalActionSend = "SEND"
private let SignalActionReply = "REPLY"
private let SignalActionCancel = "CANCEL"
private let DefaultSignalTimeout = 5


class SignalingManager {
    
    /// 信令的发送者
    var sigaler:SignalingInterface?
    
    /// 信号量，用于管理信号的收发
    private var semaphore = DispatchSemaphore(value: 1)
    
    /// 发送回调管理
    private var callbackBlocks:Dictionary<String, SignalBlock> = Dictionary()
    
    /// 信令回调
    private var delegates = NSMutableSet()
    
    /// 单例初始化接口
    static let shared = SignalingManager()
    
    // Make sure the class has only one instance
    // Should not init outside
    private init() {}
    
    // Optional
    func reset() {
        // Reset all properties to default value
    }
    
    
//MARK: - Public Method
    /// 发送信令
    /// - Parameters:
    ///   - toUserId: 目标的用户ID
    ///   - content: 用户自定义数据
    ///   - timeout: 超时时间，单位秒，默认5秒，小于等于0会取默认时间
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    /// - Returns: 信令ID，如果失败返回，nil
    func send(_ toUserId: String!, content: TextMessage!, timeout: Int32,succ:SignalingSucc?,fail:SignalingTimeout?) -> String? {
        var signalingID:String?
        let time = timeout >= 0 ? Int32(DefaultSignalTimeout) : timeout
        let signalObj = SignalingMessage(type: SignalFlag, cmd: SignalActionSend, content: content.content, key: content.key, subKey: content.subKey)
        let warpContent = jsonObjToString(jsonObj: signalObj.toJsonObj())
        signalingID = self.sigaler?.send(toUserId, content: warpContent, timeout: time, succ: {
            CCLog("send to  server sucessful:(\(signalingID ?? ""))",tag: TAG_SIGNALING)

            if (signalingID != nil) {
                let block = SignalBlock(succ: succ, fail: fail);
                //后期优化
                CCLock(self.semaphore)
                self.callbackBlocks[signalingID!] = block;
                CCUnLock(self.semaphore)
            }
        }, fail: { code, message in
            fail?(signalingID,[toUserId])
        })

        return signalingID
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
    func sendInGroup(_ groupID: String!, receiveList: [String]!, content: TextMessage!, timeout: Int32,succ:SignalingSucc?, fail:SignalingTimeout?) -> String? {
        var signalingID:String?
        let signalObj = SignalingMessage(type: SignalFlag, cmd: SignalActionSend, content: content.content, key: content.key, subKey: content.subKey)
        let warpContent = jsonObjToString(jsonObj: signalObj.toJsonObj())
        signalingID = self.sigaler?.sendInGroup(groupID, receiveList: receiveList, content: warpContent, timeout: timeout, succ:{
            CCLog("sendInGroup to  server sucessful:(\(signalingID ?? "")",tag: TAG_SIGNALING)

            if (signalingID != nil) {
                succ?()
                //PC端没有生效，先屏蔽掉
//                let block = SignalBlock(succ: succ, fail: fail);
//                CCLock(self.semaphore)
//                self.callbackBlocks[signalingID!] = block;
//                CCUnLock(self.semaphore)
            }
        }, fail: { code, message in
            fail?(signalingID,receiveList)
        })

        return signalingID
    }
    
    /// 取消信令
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - content: 用户自定义数据
    func cancel(_ signalingID: String!, content: String!,succ:SignalingSucc?,fail:SignalingTimeout?) -> Void {
        self.sigaler?.cancel(signalingID, content: content, succ:{
            CCLog("cancel to  server sucessful:(\(signalingID ?? "")",tag: TAG_SIGNALING)

            if (signalingID != nil) {
                let block = SignalBlock(succ: succ, fail: fail);
                CCLock(self.semaphore)
                
                let cancelId = self.warpCancelId(signalId: signalingID)
                self.callbackBlocks[cancelId] = block;
                
                CCUnLock(self.semaphore)
            }
        }, fail: { code, message in
            fail?(signalingID,[])
        })
    }
    
    /// 回复信令
    /// - Parameters:
    ///   - receiveID:待回复的信令ID
    ///   - content: 用户自定义数据
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    func reply(_ receiveID:String!, content:String!, succ:SignalingSucc?,fail:SignalingFail?) -> Void {
        CCLog("will reply:(\(receiveID ?? "")",tag: TAG_SIGNALING)
        let json:JSON = ["type":SignalFlag,"cmd":SignalActionReply,"content":content ?? "","key":"","subKey":""]
        let contentString = json.rawString() ?? ""
        self.sigaler?.reply(receiveID, content: contentString, succ: {
            CCLog("reply sucessful:(\(receiveID ?? "")",tag: TAG_SIGNALING)
        }, fail: { code, message in
            CCLogError("reply failed, code = \(code), message = \(message ?? "")",tag: TAG_SIGNALING);
        })

    }

    //    MARK: - 通知分发(临时处理)
    func addListener(_ listener:SignalingDelegate) {
        self.delegates.add(listener)
    }
        
    func removeListener(_ listener:SignalingDelegate) {
        self.delegates.remove(listener)
    }
}
//MARK:信令内部回调
extension SignalingManager :SigalingListener {
    /// 收到信令回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - signaler: 信令发送者
    ///   - groupID: 群ID，群发信令时需要
    ///   - receiverList: 接受者列表
    ///   - data: 自定义内容
    /// - Note: 收到信令后，需要调用reply()方法，回复对方
    func onReceiveSigaling(_ signalingID: String!, signaler: String!, groupID: String!, receiverList: [String]!, data: String?) {
        CCLog("onReceiveSigaling(\(signalingID ?? "") + from \(signaler ?? ""):\(data ?? "")",tag: TAG_SIGNALING)
            
        let jsonData = JSON(parseJSON: data ?? "")
        let type = jsonData["type"].stringValue
        let cmd = jsonData["cmd"].stringValue
        
        if type == SignalFlag && cmd == SignalActionSend {
            reply(signalingID, content: "from iOS", succ: nil, fail: nil)
            
            let content = jsonData["content"].stringValue
            let key = jsonData["key"].stringValue
            let subKey = jsonData["subKey"].stringValue

            for delegate in self.delegates {
                guard let notifier = delegate as? SignalingDelegate else {
                    return
                }
                let msg = TextMessage(content: content, key: key, subKey: subKey)
                notifier.onReceiveSigaling(signalingID, signaler: signaler, groupID: groupID, receiverList: receiverList, data: msg)
            }
        }
    }
    
    
    /// 收到信令回复的回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - receiver: 信令的接受者，发送回复指令的对象
    ///   - data: 自定义数据
    func onSigalingReply(_ signalingID: String!, receiver: String!, data: String?) {
//        CCLog("onSigalingReply(\(signalingID ?? "") + from \(receiver ?? ""):\(data ?? "")",tag: TAG_SIGNALING)
        if (signalingID != nil) {
            CCLock(self.semaphore)
            
            let block = self.callbackBlocks[signalingID!]
            block?.succ?();
            self.callbackBlocks.removeValue(forKey: signalingID!)
            
            CCUnLock(self.semaphore)
        }
    }
    
    
    /// 取消信令回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - signaler: 发起取消信令的对象
    ///   - data: 自定义数据
    func onSigalingCancelled(_ signalingID: String!, signaler: String!, data: String?) {
//        CCLog("onSigalingCancelled(\(signalingID ?? "") + from \(signaler ?? ""):\(data ?? "")",tag: TAG_SIGNALING)
        if (signalingID != nil) {
            CCLock(self.semaphore)
            
            let cancelId = warpCancelId(signalId: signalingID)
            let block = self.callbackBlocks[cancelId]
            block?.succ?();
            self.callbackBlocks.removeValue(forKey: cancelId)
            
            CCUnLock(self.semaphore)
        }
    }
    
    
    /// 信令超时回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - receiverList: 信令接收者列表，超时的对象
    func onSigalingTimeout(_ signalingID: String!, receiverList: [String]!) {
        CCLogError("onSigalingTimeout(\(signalingID ?? "") + from \(receiverList ?? [])",tag: TAG_SIGNALING)
        if (signalingID != nil) {
            CCLock(self.semaphore)
            
            let block = self.callbackBlocks[signalingID!]
            block?.fail?(signalingID,receiverList);
            self.callbackBlocks.removeValue(forKey: signalingID!)
            
            CCUnLock(self.semaphore)
        }
    }
    
    ///封装取消ID
    private func warpCancelId(signalId:String!) -> String {
        return signalId + SignalActionCancel
    }
    
}

struct SignalBlock {
    var succ:SignalingSucc?
    var fail:SignalingTimeout?
}


func CCLock(_ semaphore:DispatchSemaphore) -> Void {
    semaphore.wait()
}

func CCUnLock(_ semaphore:DispatchSemaphore) -> Void {
    semaphore.signal()
}
