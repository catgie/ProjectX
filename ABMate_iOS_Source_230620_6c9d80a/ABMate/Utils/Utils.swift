//
//  Utils.swift
//  ABMate
//
//  Created by Bluetrum on 2022/2/14.
//

import UIKit
import AVFoundation

class Utils {
    
    // MARK: - Liste des fichiers FOT disponibles
    
    static let OTA_FILE_EXTENSION = "fot"
    
    static func fotFileList() -> [URL]? {
        if let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentUrl, includingPropertiesForKeys: nil)
                // Filter
                let fotUrls = files.filter { $0.pathExtension == OTA_FILE_EXTENSION }
                return fotUrls
            } catch {
                return nil
            }
        }
        return nil
    }
    
    // MARK: - Informations sur la sortie audio
    
    static var audioOutputDevices: [AVAudioSessionPortDescription] {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.outputs
    }
    
    static var currentAudioOutputDevice: AVAudioSessionPortDescription? {
        return audioOutputDevices.first
    }
    
    static var currentAudioOutputDeviceName: String? {
        return currentAudioOutputDevice?.portName
    }
    
    static var bluetoothAudioDeviceAddress: String? {
        guard let currentAudioOutputDevice = currentAudioOutputDevice else { return nil }
        // Le format du uid des périphériques audio Bluetooth est "XX:XX:XX:XX:XX:XX-tacl"
        // Attention : Apple n'a pas officialisé ce format, il fonctionne pour l'instant (iOS 15)
        let uid = currentAudioOutputDevice.uid
        return extractBluetootAddress(uid: uid)
    }
    
    static func extractBluetootAddress(uid: String) -> String? {
        let pattern = "([0-9A-F]{2}):([0-9A-F]{2}):([0-9A-F]{2}):([0-9A-F]{2}):([0-9A-F]{2}):([0-9A-F]{2})"
        guard let range = uid.range(of: pattern, options: .regularExpression) else { return nil }
        var address = String(uid[range]) // extrait l'adresse
        address.removeAll { $0 == ":" }  // retire les deux-points
        return address
    }
    
    static func addressStringToData(_ address: String) -> Data? {
        var hex = address
        hex.removeAll { $0 == ":" }
        
        if !hex.count.isMultiple(of: 2) {
            return nil
        }
        
        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }
        
        guard hex.count / bytes.count == 2 else { return nil }
        return Data(bytes)
    }
    
    // MARK: - Nom de l'appareil
    
    static let DEVICE_NAME_PREFIX = "AB_Mate"
    
}
