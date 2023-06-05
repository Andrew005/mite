//
//  SignalingInterface.swift
//  Mitee
//
//  Created by kongfanhu on 2021/11/5.
//

import Foundation

typealias SignalingSucc = () -> Void
typealias SignalingFail = (_ code:Int32, _ message:String?) -> Void
typealias SignalingTimeout = (_ signalingID:String?, _ receiveList:[String?]) -> Void

///信令的实现接口
protocol SignalingInterface {
    /// 发送信令
    /// - Parameters:
    ///   - toUserId: 目标的用户ID
    ///   - content: 用户自定义数据
    ///   - timeout: 超时时间，单位秒，默认5秒，小于等于0会取默认时间
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    /// - Returns: 信令ID，如果失败返回，nil
    func send(_ toUserId: String!, content: String!, timeout: Int32,succ:SignalingSucc?,fail: SignalingFail?) -> String?;
    
    
    /// 群发信令
    /// - Parameters:
    ///   - groupID: 群ID
    ///   - receiveList: 接受者列表
    ///   - content: 用户自定义数据
    ///   - timeout: 超时时间，单位秒，默认5秒，小于等于0会取默认时间
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    /// - Returns: 信令ID，如果失败返回，nil
    func sendInGroup(_ groupID: String!, receiveList: [String]!, content: String!, timeout: Int32,succ:SignalingSucc?,fail:SignalingFail?) -> String?;
    
    /// 取消信令
    /// - Parameters:
    ///   - signalingId: 信令ID
    ///   - content: 用户自定义数据
    func cancel(_ signalingId: String!, content: String!,succ:SignalingSucc?,fail:SignalingFail?) -> Void;
    
    
    /// 回复信令
    /// - Parameters:
    ///   - receiveID:待回复的信令ID
    ///   - content: 用户自定义数据
    ///   - succ: 成功回调
    ///   - fail: 失败回调
    func reply(_ receiveID:String!, content:String!, succ:SignalingSucc?,fail:SignalingFail?) -> Void;
}

///信令内部更新，管理状态
protocol SigalingListener {
    /// 收到信令回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - signaler: 信令发送者
    ///   - groupID: 群ID，群发信令时需要
    ///   - receiverList: 接受者列表
    ///   - data: 自定义内容
    /// - Note: 收到信令后，需要调用reply()方法，回复对方
    func onReceiveSigaling(_ signalingID: String!, signaler: String!, groupID: String!, receiverList: [String]!, data: String?);
    
    
    /// 收到信令回复的回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - receiver: 信令的接受者，发送回复指令的对象
    ///   - data: 自定义数据
    func onSigalingReply(_ signalingID: String!, receiver: String!, data: String?);
    
    
    /// 取消信令回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - signaler: 发起取消信令的对象
    ///   - data: 自定义数据
    func onSigalingCancelled(_ signalingID: String!, signaler: String!, data: String?);
    
    
    /// 信令超时回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - receiverList: 信令接收者列表，超时的对象
    func onSigalingTimeout(_ signalingID: String!, receiverList: [String]!);
    
}


// MARK: - 信令对外回调
protocol SignalingDelegate :NSObjectProtocol{
    /// 收到信令回调
    /// - Parameters:
    ///   - signalingID: 信令ID
    ///   - signaler: 信令发送者
    ///   - groupID: 群ID，群发信令时需要
    ///   - receiverList: 接受者列表
    ///   - data: 自定义内容
    /// - Note: 收到信令后，需要调用reply()方法，回复对方
    func onReceiveSigaling(_ signalingID: String!, signaler: String!, groupID: String!, receiverList: [String]!, data: TextMessage?);
}
