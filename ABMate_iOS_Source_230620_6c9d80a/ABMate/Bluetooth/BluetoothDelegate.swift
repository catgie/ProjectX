//
//  BluetoothDelegate.swift
//  ABMate
//
//  Created by Bluetrum on 2022/2/17.
//

import Foundation
import CoreBluetooth

// MARK: - BluetoothDelegate
/*
 Protocole de délégation utilisé pour recevoir les événements Bluetooth.
 Implémentez ces méthodes optionnelles pour suivre l'état du Bluetooth,
 découvrir des périphériques et gérer les connexions.
*/
@objc public protocol BluetoothDelegate : NSObjectProtocol {
    
    /*
     Appelé lorsque l'état du Bluetooth change.
     - Parameter state: nouvel état du manager.
     */
    @objc optional func didUpdateState(_ state: CBManagerState)
    
    /*
     Indique que l'opération de scan a été stoppée.
     */
    @objc optional func didStopScanning()
    
    /*
     Appelé lorsqu'un périphérique est découvert.
     - Parameters:
       - peripheral: périphérique détecté.
       - advertisementData: données d'annonce.
       - RSSI: puissance du signal.
     */
    @objc optional func didDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String : Any], RSSI: NSNumber)
    
    /*
     Signale qu'une connexion a été établie avec succès.
     - Parameter connectedPeripheral: le périphérique connecté.
     */
    @objc optional func didConnectedPeripheral(_ connectedPeripheral: CBPeripheral)
    
    /*
     Indique qu'une tentative de connexion a échoué.
     - Parameters:
       - peripheral: périphérique concerné.
       - error: erreur éventuelle.
     */
    @objc optional func failToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    
    /*
     Appelé lors de la déconnexion d'un périphérique.
     - Parameters:
       - peripheral: périphérique concerné.
       - error: erreur éventuelle.
     */
    @objc optional func didDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?)

    /*
     Notifie un événement de connexion spécifique (iOS 13+).
     - Parameters:
       - event: type d'événement reçu.
       - peripheral: périphérique concerné.
     */
    @objc optional func connectionEventDidOccur(_ event: CBConnectionEvent, for peripheral: CBPeripheral)
}
