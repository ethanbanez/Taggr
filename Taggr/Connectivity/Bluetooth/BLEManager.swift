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


// this creates a global BLE manager
//let globalBLEManager = BLEManager(central: UUID(), peripheral: UUID())

/* we need to be able to reconnect the manager to the restored centrals */

/*
 IMPORTANT: no need to instantiate central or peripheral here. We should define the class as the delegates and implement the methods but then
 allow it to be assigned to a central and peripheral at the start of the app so that the central and peripheral managers can be reinstantiated
 */

private let defaults = UserDefaults.standard

class BLEManager: NSObject, ObservableObject {
  
  static let shared = BLEManager()
  
  private let log: Logger = Logger(subsystem: Subsystem.tag.description, category: "BLEManager")
  @Published var tagged: Bool {
    didSet {
      UserDefaults.standard.set(tagged, forKey: "isTagged")
    }
  }
  @Published var discoveredPeripherals: [CBPeripheral]?
  
  // BLEManager variables
  /* we need to receive these objects from somewhere else… in the initializer? */
  var central: CBCentralManager? {
    didSet {
      central?.delegate = self
    }
  }
  var peripheral: CBPeripheralManager? {
    didSet {
      peripheral?.delegate = self
    }
  }
  
  /* these are the uuids of the peripheral and central objects that it is managing */
  // how will I get these though if BLEManager isn't the one that makes them?
  // I can make them global variables as well…
  var peripheralUUID: UUID?
  var centralUUID: UUID?
  
  /* reference to the currently connected peripherals of the central */
  private var connectedPeripherals: [CBPeripheral]!
  
  
  /* reference to the advertisement data of the peripheral */
  private var advertisementData: [String: Any]
  
  /* this is a reference to the uuid that, when the app is a tagger, to connect to */
  private var uuidToConnectTo: UUID?
  
  // Central delegate variables
  // good for setting the delegates and conditional
  private var currentlyConnectedPeripheral: CBPeripheral?
  
  // Peripheral delegate variables
  // why store the previous characteristic value?
  private var previousCharacteristicValue: String?
  
  var tagService: TagService
  
  /* initialization */
  override init() {
    log.info("intialization in progress")
    tagged = defaults.bool(forKey: "isTagged")
    
    let serviceUUID = CBUUID(string: defaults.string(forKey: "TagServiceUUID") ?? {
      let uuid = UUID().uuidString
      defaults.set(uuid, forKey: "TagServiceUUID")
      return uuid
    }())
    
    let characteristicUUID = CBUUID(string: defaults.string(forKey: "TagCharacteristicUUID") ??  {
      let uuid = UUID().uuidString
      defaults.set(uuid, forKey: "TagCharacteristicUUID")
      return uuid
    }())
    
    tagService = TagService(serviceuuid: serviceUUID, characteristicuuid: characteristicUUID)
    
    advertisementData = [CBAdvertisementDataServiceUUIDsKey: [tagService.serviceUUID]] as [String : Any]
    super.init()
    log.info("completed initialization")
  }
  
  /* deinitialization */
  deinit {
    central?.stopScan()
    central = nil
    peripheral?.removeAllServices()
    peripheral?.stopAdvertising()
    peripheral = nil
    log.info("deinitialized")
  }
  
  
  private func updateTag(tagged: Bool) {
    log.info("updating tag status")
    transition(tagged: tagged)
    self.tagged = tagged
  }
  
  /*
   Transition from either central/peripheral to the other to reflect transitions from not tagged/tagged
   */
  private func transition(tagged: Bool) {
    // if tagged is now true then we become peripheral, otherwise we become central
    if tagged == true {
      log.info("transitioning to tagger")
      central?.stopScan()
      let connectedPeripherals = central?.retrieveConnectedPeripherals(withServices: [tagService.serviceUUID])
      if connectedPeripherals != nil {
        for connectedPeripheral in connectedPeripherals! {
          central?.cancelPeripheralConnection(connectedPeripheral)
        }
      }
      
      tagService.service.characteristics = [tagService.characteristic]
      peripheral?.add(tagService.service)
      peripheral?.startAdvertising(advertisementData)
      
    } else {
      log.info("transitioning to runner")
      peripheral?.removeAllServices()
      peripheral?.stopAdvertising()
      
      log.info("started scanning for: \(self.tagService.serviceUUID.uuidString)")
      central?.scanForPeripherals(withServices: [tagService.serviceUUID])
    }
    return
  }
  
  // View methods
  
  
  public func beginTagging() {
    
    // set a timer here for when the game begins
    log.info("starting out as tagger")
    
    self.central = BLEGroup.shared.central
    self.peripheral = BLEGroup.shared.peripheral
    
    if central?.isScanning == true {
      central?.stopScan()
    }
    self.peripheral = BLEGroup.shared.peripheral
    if peripheral?.isAdvertising == true {
      peripheral?.removeAllServices()
      peripheral?.stopAdvertising()
    }
    
    BLEGroup.shared.central = nil
    BLEGroup.shared.peripheral = nil

    updateTag(tagged: true)
  }
  
  
  public func beginRunning() {
    log.info("starting out as runner")
             
    self.central = BLEGroup.shared.central
    self.peripheral = BLEGroup.shared.peripheral
    
    if central?.isScanning == true {
      central?.stopScan()
    }
    self.peripheral = BLEGroup.shared.peripheral
    if peripheral?.isAdvertising == true {
      peripheral?.removeAllServices()
      peripheral?.stopAdvertising()
    }
    
    BLEGroup.shared.central = nil
    BLEGroup.shared.peripheral = nil
    
    updateTag(tagged: false)
  }
  
  
  
}

/*
 CENTRAL MANAGER DELEGATE METHODS
 */

extension BLEManager: CBCentralManagerDelegate {
  
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
      /* when bluetooth is powered on then we can start scanning. But we want to only scan when we're not peripheral not just when we're on... */
    case CBManagerState.poweredOn :
      log.info("powered on")
    case CBManagerState.poweredOff :
      log.info("powered off")
      central.stopScan()
    case CBManagerState.resetting :
      log.info("resetting")
    case CBManagerState.unknown :
      log.info("unknown")
    case CBManagerState.unsupported :
      log.info("unsupported")
    case CBManagerState.unauthorized :
      log.info("unauthorized")
    @unknown default:
      log.error("state not accounted for")
    }
  }
  
  
  /*
   Should assign the central variable to the returned central object
   */
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    log.info("central is restoring state")
    /* just because the state has been restored does not mean that we were tagged just that the app has been reinitialized */
    guard let centraluuid = dict[CBCentralManagerOptionRestoreIdentifierKey] as? String else {
      log.info("central no restoreIdentifier")
      return
    }
    log.info("central restoring with UUID: \(centraluuid)")
    self.central = CBCentralManager(delegate: self, queue: .global(), options: [CBCentralManagerOptionRestoreIdentifierKey: centraluuid])
    centralUUID = UUID(uuidString: centraluuid)
    log.info("central state restored")
  }
  
  
  /* this callback will be used for switching the states from scanning to advertising as a peripheral */
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // in this phase the peripheral does not know that it has been connected yet…
    // in order to actually tag someone and for both to know it it needs to go into discoverServices --> discoverCharacteristics --> issue reading of a characteristic --> respond to the read from the peripheral manager
    
    
    log.info("central connected to peripheral: \(peripheral.identifier)")
    
    central.stopScan()
    log.info("central stopped scanning")
    
    /* set the peripheral delegate to the current BLEManager */
    discoveredPeripherals?.append(peripheral)
    currentlyConnectedPeripheral?.delegate = self
    currentlyConnectedPeripheral?.discoverServices([tagService.serviceUUID])
  }
  
  
  
  /* TEST METHODS */
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    log.info("central disconnected from peripheral: \(peripheral.identifier)")
    currentlyConnectedPeripheral = nil
    central.scanForPeripherals(withServices: [tagService.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    log.info("central failed to connect to peripheral: \(peripheral.identifier)")
    /* should deal with a failed connection appropriately */
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    log.info("central discovered peripheral: \(peripheral.identifier)")
    
    if currentlyConnectedPeripheral == nil {
      currentlyConnectedPeripheral = peripheral
      
      /*
       we need to somehow wait and ask the user if they want to connect to a discoered peripheral
       instead of connecting we can update a variable displaying the connected peripheral and then there can be a button
       to tap if they want to connect to the peripheral
       */
      central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true])
    }
  }
  
}


/*
 PERIPHERAL DELEGATE METHODS
 */

extension BLEManager: CBPeripheralDelegate {
  
  /* did discover the service that we wanted */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      log.info("peripheral error while discovering services: \(error.localizedDescription)")
      return
    }
    log.info("discovered services for peripheral \(peripheral.identifier)")
    guard let peripheralServices = peripheral.services else {return}
    for service in peripheralServices where service.uuid == tagService.serviceUUID {
      peripheral.discoverCharacteristics([tagService.characteristicUUID], for: service)
    }
  }
  
  
  
  /* did discover the characteristics that we wanted as well and then we just wait for data to come in */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
    if let error = error {
      log.info("peripheral error while discovering characteristics: \(error.localizedDescription)")
      return
    }
    guard let serviceCharacteristics = service.characteristics else { return }
    
    for characteristic in serviceCharacteristics where characteristic.uuid == tagService.characteristicUUID {
      log.info("discovered characteristic \(characteristic.uuid)")
      // here we need to read the characteristic with response
      peripheral.readValue(for: characteristic)
    }
  }
  
  
  
  /* this function only called when the withResponse option is enabled?? */
  
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("peripheral error updating characteristic value: \(error.localizedDescription)")
      return
    }
    
    if characteristic.uuid == tagService.characteristicUUID {
      log.info("successful reading of characteristic")
      updateTag(tagged: true)
    }
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    log.info("peripheral modified service")
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
      log.info("peripheral manager powered on")
      
    case CBManagerState.poweredOff :
      log.info("peripheral manager powered off")
      
      /*
       should remove services here and stop advertising
       */
      if peripheral.isAdvertising {
        peripheral.stopAdvertising()
      }
      peripheral.removeAllServices()
    case CBManagerState.resetting :
      log.info("peripheral manager resetting")
    case CBManagerState.unknown :
      log.info("peripheral manager unknown")
    case CBManagerState.unsupported :
      log.info("peripheral manager unsupported")
    case CBManagerState.unauthorized :
      log.info("peripheral manager unauthorized")
    @unknown default:
      log.error("peripheral manager state not accounted for")
    }
  }
  
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
    log.info("peripheral manager is restoring state")
    
    guard let peripheraluuid = dict[CBPeripheralManagerOptionRestoreIdentifierKey] as? String else {
      log.info("peripheral manager no restoration identifier")
      return
    }
    log.info("peripheral manager restoring peripheral with UUID: \(peripheraluuid)")
    self.peripheral = CBPeripheralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: peripheraluuid])
    peripheralUUID = UUID(uuidString: peripheraluuid)
    log.info("peripheral manager state restored")
  }
  
  
  /* TEST METHODS */
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    log.info("received read request preparing to update tag status")
    if request.characteristic.uuid == tagService.characteristicUUID {
      // need to update the value of the characteristic…
      peripheral.updateValue(Data([0x1]), for: tagService.characteristic, onSubscribedCentrals: nil)
      peripheral.respond(to: request, withResult: .success)
      updateTag(tagged: false)
    }
  }
  
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    log.info("peripheral manager started advertising")
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    log.info("peripheral manager added service: \(service.uuid)")
  }
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    log.info("central \(central.identifier) subscribed to characteristic: \(characteristic.uuid)")
  }
  
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    log.info("central unsubscribed from characteristic \(characteristic.uuid)")
  }
  
  
  
  
  
}
