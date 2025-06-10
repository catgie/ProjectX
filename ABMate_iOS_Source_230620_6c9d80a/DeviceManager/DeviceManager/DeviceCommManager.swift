//
//  DeviceCommManager.swift
//  DeviceManager
//
//  Created by Bluetrum.
//  

import Foundation
import DequeModule
import Utils

// MARK: - DeviceCommManager
/*
 Gère la file d'attente des requêtes et le traitement des réponses provenant
 du périphérique. Utilisez `sendRequest` pour envoyer une commande et recevez
 le résultat via les callbacks associés.
*/

public typealias RequestCompletion = (_ request: Request, _ result: Any?,  _ timeout: Bool) -> Void

public typealias NotificationCallback = (_ notification: Any) -> Void
public typealias NotificationHandler = (callableType: Any, callback: NotificationCallback)

public typealias DeviceInfoCallback = (_ deviceInfo: Any) -> Void
public typealias DeviceInfoHandler = (callableType: Any, callback: DeviceInfoCallback)

public protocol DeviceCommDelegate: AnyObject {
    func sendRequestData(_ requestData: RequestData)
}

public protocol DeviceResponseErrorHandler: AnyObject {
    func onError(_ error: ResponseError)
}

/*
 Gestionnaire principal des communications avec l'appareil.
 Il sérialise les requêtes et distribue les réponses ou notifications.
*/
open class DeviceCommManager {
    
    private let requestHandler: RequestHandler
    private let responseHandler: ResponseHandler
    
    public weak var commDelegate: DeviceCommDelegate?
    public weak var responseErrorHandler: DeviceResponseErrorHandler?
    
    private var requestQueue: Deque<Request> = Deque()
    // If the request is present indicates it has been sent and is waiting for response
    private var currentRequest: Request? = nil
    
    private var requestLock: NSLock = NSLock()
    
    // 超时
    private var timeoutMap: [Request: DispatchWorkItem] = [:]
    private let timeoutQueue: DispatchQueue = DispatchQueue(label: "Request Timeout")
    
    // 请求命令
    private var requestCompletionMap: [Request: RequestCompletion] = [:]
    
    // 消息回复
    private var responseCallableTypeMap: [UInt8: Any] = [:]

    // 通知
    private var notificationHandlers: [UInt8: NotificationHandler] = [:]
    
    // 设备信息等上报型信息
    private var deviceInfoHandlers: [UInt8: DeviceInfoHandler] = [:]
    
    public var maxPacketSize: Int {
        get {
            requestHandler.maxPayloadSize
        }
        set {
            requestHandler.maxPayloadSize = newValue
        }
    }
    
    
    /*
     Initialise les gestionnaires de requêtes et de réponses.
     */
    public init() {
        self.requestHandler = RequestHandler()
        self.responseHandler = ResponseHandler()
        self.responseHandler.delegate = self
    }
    
    /*
     Envoie une requête sans attendre de résultat spécifique.
     */
    open func sendRequest(_ request: Request) {
        sendRequest(request, completion: nil)
    }
    
    /*
     Envoie une requête avec un callback optionnel exécuté à la réception de la réponse.
     - Parameters:
       - request: requête à transmettre.
       - completion: bloc appelé avec le résultat ou en cas de timeout.
     */
    open func sendRequest(_ request: Request, completion: RequestCompletion?) {
        
        if let completion = completion {
            
            // 超时
            let timeoutCallback = DispatchWorkItem { [weak self] in
                self?.currentRequest = nil
                // 超时的同时发出下一个请求
                self?.nextRequest()
                
                self?.requestLock.lock()
                self?.requestCompletionMap.removeValue(forKey: request)
                self?.timeoutMap.removeValue(forKey: request)
                self?.requestLock.unlock()
                
                DispatchQueue.main.async {
                    completion(request, nil, true)
                }
            }
            requestLock.lock()
            requestCompletionMap[request] = completion
            timeoutMap[request] = timeoutCallback
            requestLock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(request.timetout), execute: timeoutCallback)
        }
        
        requestQueue.append(request)
        nextRequest()
    }
    
    @discardableResult
    /*
     Annule une requête spécifique si elle se trouve dans la file d'attente.
     - Parameter request: requête à supprimer.
     - Returns: vrai si la requête a été retirée.
     */
    public func cancelRequest(_ request: Request) -> Bool {
        requestLock.lock()
        if let index = requestQueue.firstIndex(of: request) {
            requestQueue.remove(at: index)
            requestCompletionMap.removeValue(forKey: request)
            if let timeoutCallback = timeoutMap.removeValue(forKey: request) {
                timeoutCallback.cancel()
            }
            requestLock.unlock()
            return true
        }
        requestLock.unlock()
        return false
    }
    
    /*
     Vide la file d'attente et annule les timeouts associés.
     */
    public func cancelAllRequests() {
        requestLock.lock()
        while let request = requestQueue.popFirst() {
            requestCompletionMap.removeValue(forKey: request)
            if let timeoutCallback = timeoutMap.removeValue(forKey: request) {
                timeoutCallback.cancel()
            }
        }
        requestLock.unlock()
    }
    
    private func nextRequest() {
        guard currentRequest == nil else {
            return
        }
        if let request = requestQueue.popFirst() {
            if request.leWriteWithResponse {
                currentRequest = request
            }
            
            var requestDataQueue = requestHandler.handleRequest(request)
            while let requestData = requestDataQueue.popFirst() {
                commDelegate?.sendRequestData(requestData)
            }
        }
    }
    
    /*
     Traite les données brutes reçues du périphérique.
     */
    public func handleData(_ data: Data) {
        responseHandler.handleFrameData(data)
    }

    /*
     Réinitialise les files d'attente ainsi que les gestionnaires internes.
     */
    public func reset() {
        cancelAllRequests()
        requestHandler.reset()
        responseHandler.reset()
    }
    
    // MARK: - Device Info
    /*
     Enregistre un gestionnaire pour les informations renvoyées par l'appareil.
     - Parameters:
       - deviceInfoType: identifiant de l'information.
       - callableType: type capable de décoder la réponse.
       - callback: bloc exécuté avec l'objet décodé.
     */
    public func registerDeviceInfoCallback<T: PayloadHandler>(_ deviceInfoType: UInt8, callableType: T.Type, callback: @escaping DeviceInfoCallback) {
        deviceInfoHandlers[deviceInfoType] = (callableType, callback)
    }

    /*
     Supprime le gestionnaire associé à un type d'information.
     */
    public func unregisterDeviceInfoCallback(_ deviceInfoType: UInt8) {
        deviceInfoHandlers[deviceInfoType] = nil
    }
    
    // MARK: - Notification
    /*
     Permet de recevoir des notifications émanant de l'appareil.
     - Parameters:
       - notifyType: identifiant de la notification.
       - callableType: type permettant de décoder les données.
       - callback: bloc exécuté lorsqu'une notification est reçue.
     */
    public func registerNotificationCallback<T: PayloadHandler>(_ notifyType: UInt8, callableType: T.Type, callback: @escaping NotificationCallback) {
        notificationHandlers[notifyType] = (callableType, callback)
    }

    /*
     Supprime le gestionnaire de notification pour un type donné.
     */
    public func unregisterNotificationCallback(_ notifyType: UInt8) {
        notificationHandlers[notifyType] = nil
    }

    // MARK: - Response
    /*
     Associe un type de décodage à une commande de réponse.
     */
    public func registerResponseCallable<T: PayloadHandler>(command: UInt8, callableType: T.Type) {
        responseCallableTypeMap[command] = callableType
    }

    /*
     Enregistre plusieurs associations commande/type en une fois.
     */
    public func registerResponseCallables(_ entries: [UInt8: PayloadHandler.Type]) {
        for (command, callableType) in entries {
            responseCallableTypeMap[command] = callableType
        }
    }

    /*
     Supprime l'association pour une commande donnée.
     */
    public func unregisterResponseCallable(command: UInt8) {
        responseCallableTypeMap[command] = nil
    }
    
}

// MARK: - 设备信息处理

public extension DeviceCommManager {
    /*
     Décode une information de type donné et exécute le callback enregistré.
     */
    func processDeviceInfo(type: UInt8, data: Data) {
        
        if let handler = deviceInfoHandlers[type],
           let callableType = handler.callableType as? PayloadHandler.Type {
            
            let callable = callableType.init(data)
            if let result = callable() {
                DispatchQueue.main.async {
                    handler.callback(result)
                }
            } else {
                // 数据处理错误
                print("deviceInfoCallable returns nil, check \(callableType) and data(\(data.hex))")
            }
        }
    }
    
    /*
     Parcourt un bloc de données contenant plusieurs informations TLV.
     */
    func processDeviceInfoData(_ data: Data) {
        let bb = ByteBuffer.wrap(data)
        
        while bb.remainning >= 2 {
            let infoType = bb.get()
            let infoLen = bb.get()
            
            if infoLen <= bb.remainning {
                var infoData = Data(count: Int(infoLen))
                bb.get(&infoData)
                
                processDeviceInfo(type: infoType, data: infoData)
            }
        }
    }
    
}

// MARK: - 设备通知处理

fileprivate extension DeviceCommManager {
    /*
     Traite une notification unique en invoquant le callback correspondant.
     */
    private func processNotification(command: UInt8, data: Data) {
        
        if let handler = notificationHandlers[command],
           let callableType = handler.callableType as? PayloadHandler.Type {
            
            let notificationCallable = callableType.init(data)
            if let result = notificationCallable() {
                DispatchQueue.main.async {
                    handler.callback(result)
                }
            } else {
                // 数据处理错误
                print("notificationCallable returns nil, check \(callableType) and data(\(data.hex))")
            }
        }
    }
    
    /*
     Décompose un bloc TLV contenant plusieurs notifications.
     */
    private func processNotificationData(_ data: Data) {
        
        let bb = ByteBuffer.wrap(data)
        
        while bb.remainning >= 2 {
            let notificationCommand = bb.get()
            let notificationLen = bb.get()
            
            if notificationLen <= bb.remainning {
                var notificationData = Data(count: Int(notificationLen))
                bb.get(&notificationData)
                
                processNotification(command: notificationCommand, data: notificationData)
            }
        }
    }
    
}

// MARK: - ResponseHandlerDelegate

extension DeviceCommManager: ResponseHandlerDelegate {
    /*
     Réception d'une notification décodée par le ResponseHandler.
     */
    public func didReceiveNotification(_ notification: Notification) {
        
        let notificationCommand = notification.getCommand()
        let notificationData = notification.getPayload()
        
        // COMMAND_NOTIFY的格式属于TLV，单独处理
        if notificationCommand == Command.COMMAND_NOTIFY {
            processNotificationData(notificationData)
        } else {
            processNotification(command: notificationCommand, data: notificationData)
        }
    }
    
    /*
     Appelé lorsqu'une réponse complète est reçue.
     Gère la file d'attente et exécute le callback adéquat.
     */
    public func didReceiveResponse(_ response: Response) {
        currentRequest = nil
        // Handle next request when received response
        nextRequest()
        
        requestLock.lock()
        // Find corresponding request of the response in CompletionMap
        let request = requestCompletionMap.filter({ $0.key.getCommand() == response.getCommand() }).first?.key
        // Remove timeout handler
        if let request = request,
           let timeoutCallback = timeoutMap.removeValue(forKey: request) {
            timeoutCallback.cancel()
        }
        requestLock.unlock()
        
        let responseCommand = response.getCommand()
        let responseData = response.getPayload()
        
        // Handle response data
        if responseCommand == Command.COMMAND_DEVICE_INFO {
            var requestCompletion: RequestCompletion?
            // Remove callback if exist
            if let request = request {
                requestLock.lock()
                requestCompletion = requestCompletionMap.removeValue(forKey: request)
                requestLock.unlock()
            }
            processDeviceInfoData(responseData)
            // 处理完获取设备信息之后，如果有回调，不论如何调用一下，表明处理完毕
            if let request = request, let requestCompletion = requestCompletion {
                DispatchQueue.main.async {
                    requestCompletion(request, true, false)
                }
            }
        } else if let request = request {
            // Callback
            requestLock.lock()
            let requestCompletion = requestCompletionMap.removeValue(forKey: request)
            requestLock.unlock()
            if let requestCompletion = requestCompletion,
               let responseCallableType = responseCallableTypeMap[responseCommand] as? PayloadHandler.Type {
                
                let responseCallable = responseCallableType.init(responseData)
                let result = responseCallable()
                
                // Run in main thread
                DispatchQueue.main.async {
                    requestCompletion(request, result as Any, false)
                }
            }
        }
    }
    
    /*
     Relaye les erreurs de décodage au gestionnaire externe.
     */
    public func onError(_ error: ResponseError) {
        responseErrorHandler?.onError(error)
    }
    
}
