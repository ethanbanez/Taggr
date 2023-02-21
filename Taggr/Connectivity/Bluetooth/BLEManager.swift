//
//  BLEManager.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/11/23.
//

import Foundation
import CoreBluetooth
import UIKit
import SwiftUI
import os

/* an object that manages the both the central and peripheral parts of the device */
/* should it be a struct or a class? */
/* should this also be the peripheral and central delegate so then  */



/* we need to be able to reconnect the manager to the restored centrals */
class BLEManager: NSObject, ObservableObject {
  
  private let log: Logger = Logger(subsystem: Subsystem.connectivity.description, category: "BLEManager")
  @State var tagged: Bool
  @State var discoveredPeripherals: [CBPeripheral]?
  
  // BLEManager variables
  /* we need to receive these objects from somewhere else… in the initializer? */
  var central: CBCentralManager!
  var peripheral: CBPeripheralManager!
  
  /* reference to the currently connected peripherals of the central */
  var connectedPeripherals: [CBPeripheral]!
  
  
  /* reference to the advertisement data of the peripheral */
  private var advertisementData: [String: Any]
  
  /* this is a reference to the uuid that, when the app is a tagger, to connect to */
  private var uuidToConnectTo: UUID?
  
  /* these are the uuids of the peripheral and central objects that it is managing */
  private var peripheralUUID: UUID
  private var centralUUID: UUID
  
  
  // Central delegate variables
  var currentlyConnectedPeripheral: CBPeripheral!
  
  // Peripheral delegate variables
  var previousCharacteristicValue: String!
  
  /* initialization */
  init(central: UUID, peripheral: UUID) {
    log.info("BLEManager intialization in progress")
    tagged = UserDefaults.standard.bool(forKey: "isTagged")
    
    self.centralUUID = central
    self.peripheralUUID = peripheral
    // this can only be run when the bluetooth power is on!
    /* set up ad Data and service */
//    self.peripheral.manager.add(tagService.service)
    
    advertisementData = [CBAdvertisementDataServiceUUIDsKey: [TagService.serviceUUID]] as [String : Any]
    
    // must retrieve connecte peripherals during initialization??
//    self.connectedPeripherals = central.manager.retrieveConnectedPeripherals(withServices: [tagService.service.uuid])
    
    super.init()
    
    self.central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: central.uuidString])
    self.peripheral = CBPeripheralManager(delegate: self, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheral.uuidString])
    log.info("BLEManager completed initialization")
  }
  
  /* deinitialization */
  deinit {
    central.stopScan()
    peripheral.stopAdvertising()
    log.info("BLEManager is deinitialized")
  }
  
  
  // Central delegate helper methods
  
  private func retrievePeripherals() {
    let knownConnectedPeripherals: [CBPeripheral] = central.retrieveConnectedPeripherals(withServices: [TagService.serviceUUID])
    if let peripheral: CBPeripheral = knownConnectedPeripherals.last {
      central.connect(peripheral)
    } else {
      /* may want to make CBCentralManagerScanOptionAllowDuplicatesKey: false when in actuality since we just want to connect as soon as in range */
      log.info("centralDelegate retrievingPeripherals is scanning for service: \(TagService.serviceUUID)")
      central.scanForPeripherals(withServices: [TagService.serviceUUID],
                                 options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
  }
  
  
  // View methods
  
  
}

/*
 CENTRAL MANAGER DELEGATE METHODS
 */

extension BLEManager: CBCentralManagerDelegate {
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
      /* when bluetooth is powered on then we can start scanning. But we want to only scan when we're not peripheral not just when we're on... */
    case CBManagerState.poweredOn :
      log.info("centralManagerDidUpdateState powered on")
      let minorVersion = ProcessInfo().operatingSystemVersion.minorVersion
      switch minorVersion {
      case 5:
        retrievePeripherals()
      default:
        log.info("I am the iPad")
      }
      log.info("centralManagerDidUpdateState scanning for services with CBUUID: \(TagService.serviceUUID)")
    case CBManagerState.poweredOff :
      log.info("centralManagerDidUpdateState powered off")
      central.stopScan()
    case CBManagerState.resetting :
      log.info("centralManagerDidUpdateState resetting")
    case CBManagerState.unknown :
      log.info("centralManagerDidUpdateState unknown")
    case CBManagerState.unsupported :
      log.info("centralManagerDidUpdateState unsupported")
    case CBManagerState.unauthorized :
      log.info("centralManagerDidUpdateState unauthorized")
    @unknown default:
      log.error("centralManagerDidUpdateState state not accounted for")
    }
  }
  
  /*
   This callback function is executed when coming back from the background to continue doing a process
   We want to use this functionality on certain times that they connect
   this method is in the event that a central device connects to the peripheral it's been looking for
   */
  /* willRestoreState stores dictionaries of strings assosciated with what we want to restore */
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    log.info("BLEManager centralManager is restoring state")
    /* just because the state has been restored does not mean that we were tagged just that the app has been reinitialized */
    guard let id = dict[CBCentralManagerOptionRestoreIdentifierKey] as? String else {return}
    self.central = CBCentralManager(delegate: self, queue: .global(), options: [CBCentralManagerOptionRestoreIdentifierKey: id])
    
    /* this callback will be used for switching the states from scanning to advertising as a peripheral */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      log.info("centralDelegate didConnect to peripheral: \(peripheral.identifier)")
      
      central.stopScan()
      log.info("centralDelegate didConnect stopped scanning")
      
      /* set the peripheral delegate to the current BLEManager */
      peripheral.delegate = self
      
      peripheral.discoverCharacteristics([TagService.characteristicUUID], for: TagService.service)
      
      var myPeripheralUUID: Data = Data()
      withUnsafeBytes(of: self.peripheralUUID.uuid, {myPeripheralUUID.append(contentsOf: $0)})
      log.info("centralDelegate didConnect writing bytes: \(myPeripheralUUID) to peripheral: \(peripheral.identifier)")
      peripheral.writeValue(myPeripheralUUID, for: TagService.characteristic, type: .withoutResponse)
    }
    
    /* TEST METHODS */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
      log.info("centralDelegate didDisconnectPeriphera from peripheral: \(peripheral.identifier)")
      currentlyConnectedPeripheral = nil
      
      retrievePeripherals()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
      log.info("centralDelegate didFailToConnect to peripheral: \(peripheral.identifier)")
      /* should deal with a failed connection appropriately */
    }
    
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
      switch event {
      case CBConnectionEvent.peerConnected:
        log.info("centralDelegate connectionEventDidOccur peer connected with peripheral: \(peripheral.identifier)")
      case CBConnectionEvent.peerDisconnected:
        log.info("centralDelegate connectionEventDidOccur peer disconnected with peripheral: \(peripheral.identifier)")
      @unknown default:
        log.info("centralDelegate connectionEventDidOccur unknown event with peripheral: \(peripheral.identifier)")
      }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
      log.info("centralDelegate didDiscover peripheral: \(peripheral.identifier) with ad data: \(advertisementData.description)")
      
      if currentlyConnectedPeripheral != peripheral {
        currentlyConnectedPeripheral = peripheral
        log.info("centralDelegate didDiscover connecting to peripheral")
        
        /*
            we need to somehow wait and ask the user if they want to connect to a discoered peripheral
            instead of connecting we can update a variable displaying the connected peripheral and then there can be a button
            to tap if they want to connect to the peripheral
         */
        central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true])
      }
      
    }
    
  }
}


/*
 PERIPHERAL DELEGATE METHODS
 */

extension BLEManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    log.info("periperalDelegate didModifyServices")
    for service in invalidatedServices where service.uuid == TagService.serviceUUID {
      log.info("peripheralDelegate didModifyServices \(TagService.serviceUUID) has been invalidated")
      peripheral.discoverServices([TagService.serviceUUID])
    }
  }
  
  /* did discover the service that we wanted */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didDiscoverServices error while discovering services: \(error.localizedDescription)")
      return
    }
    log.info("peripheralDelegate didDiscoverServices discovered services for peripheral \(peripheral.identifier)")
    guard let peripheralServices = peripheral.services else {return}
    for service in peripheralServices {
      peripheral.discoverCharacteristics([TagService.characteristicUUID], for: service)
    }
  }
  
  /* did discover the characteristics that we wanted as well and then we just wait for data to come in */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
    if let error = error {
      log.info("peripheralDelegate didDiscoverCharactersticsFor error while discovering characteristics: \(error.localizedDescription)")
      return
    }
    
    log.info("peripheralDelegate didDiscoverCharactersticsFor service: \(service.uuid)")
    guard let serviceCharacteristics = service.characteristics else { return }
    
    for characteristic in serviceCharacteristics where characteristic.uuid == TagService.characteristicUUID {
      log.info("peripheralDelegate didDiscoverCharactersticsFor discovered characteristic \(characteristic.uuid)")
      let charData = characteristic.value
      previousCharacteristicValue = String(data: charData!, encoding: .utf8)
    }
  }
  
  /* this function only called when the withResponse option is enabled?? */
  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didWriteValueFor error while writing to characteristi: \(error.localizedDescription)")
      return
    }
    
    let charData = characteristic.value
    let newValue = String(data: charData!, encoding: .utf8)!
    log.info("peripheralDelegate didWriteValueFor characteristic \(characteristic.uuid) received value \(newValue)")
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didUpdateValueFor error updating characteristic value: \(error.localizedDescription)")
      return
    }
    
    let charData = characteristic.value
    let newValue = String(data: charData!, encoding: .utf8)!
    log.info("peripheralDelegate didUpdateValueFor successfully updated value for characteristic: \(characteristic.uuid) from \(self.previousCharacteristicValue) to \(newValue)")
    previousCharacteristicValue = newValue
    
  }
}


/*
 PERIPHERAL MANAGER DELEGATE METHODS
 */

extension BLEManager: CBPeripheralManagerDelegate {
  
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    /* when bluetooth is powered on then we can start scanning. But we want to only scan when we're not peripheral not just when we're on... */
    case CBManagerState.poweredOn :
      log.info("peripheralManagerDidUpdateState powered on")
      let minorVersion = ProcessInfo().operatingSystemVersion.minorVersion
      
      switch minorVersion {
      case 6:
        TagService.service.characteristics = [TagService.characteristic]
        log.info("TagService service characteristics \(TagService.service.characteristics!.count)")
        peripheral.add(TagService.service)
        peripheral.startAdvertising(advertisementData)
      default:
        log.info("I am the iPhone")
      }
      
    case CBManagerState.poweredOff :
      log.info("peripheralManagerDidUpdateState powered off")
      
      /*
        should remove services here and stop advertising
       */
      peripheral.removeAllServices()
      peripheral.stopAdvertising()
    case CBManagerState.resetting :
      log.info("peripheralManagerDidUpdateState resetting")
    case CBManagerState.unknown :
      log.info("peripheralManagerDidUpdateState unknown")
    case CBManagerState.unsupported :
      log.info("peripheralManagerDidUpdateState unsupported")
    case CBManagerState.unauthorized :
      log.info("peripheralManagerDidUpdateState unauthorized")
    @unknown default:
      log.error("peripheralManagerDidUpdateState state not accounted for")
    }
  }
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
    log.info("peripheralManagerDelegate is restoring state")
  }
  
  
  /* TEST METHODS */
  
  /* This callback can be used to transition and write the connected BLEManager's peripheral's uuid */
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    /*
        Use this function to write the connected manager's peripherals uuid
        so that when this transitions from peripheral to central it has a uuid to connect to…
     */
    for request in requests {
      guard let requestValue = request.value, let uuid = String(data: requestValue, encoding: .utf8) else {
        log.info("peripheralManagerDelegate didReceiveWrite no write value sent")
        continue
      }
      
      log.info("peripheralManagerDelegate didReceiveWrite with value: \(uuid)")
      uuidToConnectTo = UUID(uuidString: uuid)
      /* optional will need fixing */
    }
  }
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    log.info("peripheralManagerDelegate started advertising")
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    log.info("peripheralManagerDelegate didSubscribeTo central \(central.identifier) subscribed to characteristic: \(characteristic.uuid)")
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    log.info("peripheralManagerDelegate didUnsubscribeFrom central unsubscribed from characteristic \(characteristic.uuid)")
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    log.info("peripheralManagerDelegate didAdd service \(service.uuid) added")
  }
}
