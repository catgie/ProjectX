//
//  BluetoothManager.swift
//  ABMate
//
//  Created by Bluetrum on 2022/2/17.
//

import Foundation
import CoreBluetooth
import Utils

/// Sur iOS, la gestion du Bluetooth se fait via un singleton ;
/// elle n'est donc pas intégrée directement à la bibliothèque.
public class BluetoothManager: NSObject {
    
    weak var logger: LoggerDelegate? = DefaultLogger.shared
    
    let SCAN_TIMEOUT: TimeInterval = 30 // In second, default 30s

    public static let shared = BluetoothManager()
    
    public weak var delegate: BluetoothDelegate?
    
    private var centralManager: CBCentralManager
    private var peripheral: CBPeripheral?
    
    private var isOpened: Bool = false
    
    private override init() {
        centralManager = CBCentralManager()
        super.init()
        centralManager.delegate = self
    }
    
    // MARK: - Public API
    
    /// Démarre la recherche d'appareils Bluetooth
    public func startScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }
    
    @objc
    public func stopScanning() {
        centralManager.stopScan()
        delegate?.didStopScanning?()
    }
    
    @available(iOS 13.0, *)
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]? = nil) {
        centralManager.registerForConnectionEvents(options: options)
    }
    
    public func connect(_ peripheral: CBPeripheral, options: [String : Any]? = nil) {
        if self.peripheral != nil {
            centralManager.cancelPeripheralConnection(self.peripheral!)
        }
        
        self.peripheral = peripheral

        if centralManager.state == .poweredOn && peripheral.state == .disconnected {
            centralManager.connect(peripheral, options: options)
        }
        isOpened = true
    }
    
    public func disconnect(_ peripheral: CBPeripheral) {
        guard let peripheral = self.peripheral else {
            return
        }

        if peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        self.peripheral = nil
        isOpened = false
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger?.i(.bluetoothManager, "Central Manager state changed to \(central.state)")
        delegate?.didUpdateState?(central.state)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        delegate?.didDiscoverPeripheral?(peripheral, advertisementData: advertisementData, RSSI: RSSI)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.didConnectedPeripheral?(peripheral)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger?.w(.bluetoothManager, error)
        } else {
            logger?.d(.bluetoothManager, "Device is disconnected")
        }
        delegate?.failToConnectPeripheral?(peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.delegate?.didDisconnectPeripheral?(peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        self.delegate?.connectionEventDidOccur?(event, for: peripheral)
    }
    
}

extension CBManagerState: CustomDebugStringConvertible {
    
    /// Description de l'état de connexion Bluetooth
    public var debugDescription: String {
        switch self {
        case .unknown: return ".unknown"
        case .resetting: return ".resetting"
        case .unsupported: return ".unsupported"
        case .unauthorized: return ".unauthorized"
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        default: return "Unknown"
        }
    }
    
}
