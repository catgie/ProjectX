//
//  ScannerViewModel.swift
//  ABMate
//
//  Created by Bluetrum on 2022/4/15.
//

import Foundation
import RxRelay
import CoreBluetooth
import DeviceManager

class ScannerViewModel: BaseViewModel {
    
    static let shared = ScannerViewModel()
    
    // MARK: - Appareils découverts lors du scan
    
    func startScanning() {
        sharedDeviceRepo.startScanning()
    }
    
    func stopScanning() {
        sharedDeviceRepo.stopScanning()
    }
    
    var latestDiscoveredPeripheral: BehaviorRelay<ABDevice?> {
        return sharedDeviceRepo.latestDiscoveredDevice
    }
    
    var discoveredPeripherals: BehaviorRelay<[ABDevice]> {
        return sharedDeviceRepo.discoveredDevices
    }
    
}
