//
//  BluetoothDelegate.swift
//  ABMate
//
//  Created by Bluetrum on 2022/2/17.
//

import Foundation
import CoreBluetooth

/**
 *  Bluetooth Model Delegate
 */
@objc public protocol BluetoothDelegate : NSObjectProtocol {
    
    /**
     The callback function when the bluetooth has updated.
     
     - parameter state: The newest state
     */
    @objc optional func didUpdateState(_ state: CBManagerState)
    
    /**
     The callback function when the bluetooth scanning is stopped.
     */
    @objc optional func didStopScanning()
    
    /**
     The callback function when peripheral has been found.
     
     - parameter peripheral:        The peripheral has been found.
     - parameter advertisementData: The advertisement data.
     - parameter RSSI:              The signal strength.
     */
    @objc optional func didDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String : Any], RSSI: NSNumber)
    
    /**
     The callback function when central manager connected the peripheral successfully.
     
     - parameter connectedPeripheral: The peripheral which connected successfully.
     */
    @objc optional func didConnectedPeripheral(_ connectedPeripheral: CBPeripheral)
    
    /**
     The callback function when central manager failed to connect the peripheral.
     
     - parameter connectedPeripheral: The peripheral which connected failure.
     - parameter error:               The connected failed error message.
     */
    @objc optional func failToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    
    /**
    The callback function when the peripheral disconnected.

    - parameter peripheral: The peripheral which provide this action
    - parameter error:      The disconnected error message.
    */
    @objc optional func didDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?)

    /**
    The callback function when the connection event did occur.

    - parameter event:      The connection event occurs.
    - parameter peripheral: The peripheral which has the event.
    */
    @objc optional func connectionEventDidOccur(_ event: CBConnectionEvent, for peripheral: CBPeripheral)
}
