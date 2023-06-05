//
//  RequsetPlugin.swift
//  Miitee
//
//  Created by kongfanhu on 2022/12/14.
//

import Foundation
import Moya

//MARK: - 针对Response处理的插件
/// 对response提前进行拦截处理
class NetWorkResponsePlugin: PluginType {
    func willSend(_ request: RequestType, target: TargetType) {
        CCLog("开始请求:\(request.request?.url?.absoluteString ?? "")",tag: "NetWork")
    }
       
   func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
       switch result {
       case .success(let response):
           CCLog("结束请求:\(response.response?.url?.relativePath ?? "")",tag: "NetWork")
           
//           guard let query = response.request?.url?.absoluteString.urlParameters else { return }
//           
//           let data = ServiceUnreachableData(result: true, msg: "", httpCode: response.statusCode, responseCode: 0, path: response.request?.url?.relativePath ?? "", method: response.request?.method?.rawValue ?? "GET", query: query)
//           WukongCollectorApi().networkUnreachableEvent(data)
       case .failure(let moyaError):
           CCLog("结束请求 Response Code:\(String(describing: moyaError.response?.statusCode)),\(moyaError.localizedDescription)",tag: "NetWork")
           guard let response = try? result.get() else {
               return
           }
           
           guard let query = response.request?.url?.absoluteString.urlParameters else { return }
           
           let data = ServiceUnreachableData(result: true, msg: "", httpCode: response.statusCode, responseCode: 0, path: response.request?.url?.relativePath ?? "", method: response.request?.method?.rawValue ?? "GET", query: query)
           WukongCollectorApi().networkUnreachableEvent(data)
           
       }
   }
}
