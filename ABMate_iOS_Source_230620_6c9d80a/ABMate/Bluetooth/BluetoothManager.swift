//
//  BluetoothManager.swift
//  ABMate
//
//  Created by Bluetrum on 2022/2/17.
//

import Foundation
import CoreBluetooth
import Utils

// MARK: - BluetoothManager
/*
 Classe responsable de la gestion du Bluetooth.
 Utilisation : accédez à l'instance unique via `BluetoothManager.shared` puis
 appelez les méthodes exposées pour scanner, se connecter ou se déconnecter
 d'un périphérique BLE.
*/

/// Sur iOS, la gestion du Bluetooth se fait via un singleton ;
/// elle n'est donc pas intégrée directement à la bibliothèque.
public class BluetoothManager: NSObject {
    
    weak var logger: LoggerDelegate? = DefaultLogger.shared
    
    let SCAN_TIMEOUT: TimeInterval = 30 // In second, default 30s

    /*
     Instance unique du gestionnaire Bluetooth.
     Utilisez cette propriété pour accéder aux fonctionnalités de la classe.
     */
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

    /*
     Lance un scan Bluetooth pour détecter les périphériques à proximité.
     A appeler avant toute tentative de connexion.
     */
    public func startScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
    }

    @objc
    /*
     Arrête la recherche d'appareils en cours et notifie le délégué.
     */
    public func stopScanning() {
        centralManager.stopScan()
        delegate?.didStopScanning?()
    }

    @available(iOS 13.0, *)
    /*
     Enregistre l'application pour recevoir les événements système liés aux connexions Bluetooth.
     - Parameter options: dictionnaire optionnel de paramètres.
     */
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]? = nil) {
        centralManager.registerForConnectionEvents(options: options)
    }

    /*
     Tente une connexion vers le périphérique spécifié.
     - Parameters:
       - peripheral: périphérique cible.
       - options: options de connexion éventuelles.
     */
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
    
    /*
     Déconnecte le périphérique actuellement connecté s'il existe.
     - Parameter peripheral: périphérique à déconnecter.
     */
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

    /*
     Notifie le changement d'état de l'adaptateur Bluetooth.
     */
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger?.i(.bluetoothManager, "Central Manager state changed to \(central.state)")
        delegate?.didUpdateState?(central.state)
    }

    /*
     Appelé lorsqu'un périphérique est découvert durant le scan.
     */
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        delegate?.didDiscoverPeripheral?(peripheral, advertisementData: advertisementData, RSSI: RSSI)
    }

    /*
     Signal que la connexion avec le périphérique a réussi.
     */
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        delegate?.didConnectedPeripheral?(peripheral)
    }

    /*
     Indique que la connexion a échoué.
     */
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger?.w(.bluetoothManager, error)
        } else {
            logger?.d(.bluetoothManager, "Device is disconnected")
        }
        delegate?.failToConnectPeripheral?(peripheral, error: error)
    }

    /*
     Appelé lors de la déconnexion d'un périphérique.
     */
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.delegate?.didDisconnectPeripheral?(peripheral, error: error)
    }

    /*
     Relaye les événements de connexion iOS 13+ au délégué.
     */
    public func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        self.delegate?.connectionEventDidOccur?(event, for: peripheral)
    }
    
}

// MARK: - CBManagerState
extension CBManagerState: CustomDebugStringConvertible {

    /*
     Fournit une description texte de l'état Bluetooth pour le débogage.
     */
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
