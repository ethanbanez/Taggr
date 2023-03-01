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
  private var numberOfWrites = 0
  
  // Peripheral delegate variables
  // why store the previous characteristic value?
  private var previousCharacteristicValue: String?
  
  var tagService: TagService
  
  /* initialization */
  override init() {
    log.info("BLEManager intialization in progress")
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
//    if ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 3 {
//      updateTag(tagged: false)
//    }
    log.info("BLEManager completed initialization")
  }
  
  /* deinitialization */
  deinit {
    central?.stopScan()
    central = nil
    peripheral?.removeAllServices()
    peripheral?.stopAdvertising()
    peripheral = nil
    log.info("BLEManager is deinitialized")
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
      log.info("Got tagged; transitioning to peripheral")
      central?.stopScan()
      
      tagService.service.characteristics = [tagService.characteristic]
      peripheral?.add(tagService.service)
      peripheral?.startAdvertising(advertisementData)
      
    } else {
      log.info("successfully tagged; transitioning to central")
      peripheral?.removeAllServices()
      peripheral?.stopAdvertising()
      
      central?.connect(retrievePeripheral(uuid: uuidToConnectTo!))
    }
    return
  }
  
  
  
  // Central delegate helper methods
  private func retrievePeripheral(uuid: UUID) -> CBPeripheral {
    log.info("retrieving peripheral with uuid: \(uuid.uuidString)")
    let specificPeripheral = central?.retrievePeripherals(withIdentifiers: [uuid])
    
    /*
     if the following optional errors out because it is nil that means they have not connected before…
      that means that they were not connected at the beginning of the game so they didn't go through
      the synchronization process
     */
    return (specificPeripheral?.last)!
  }
  
  
  
  private func retrievePeripherals() {
    
    if let myCentral = central {
      let knownConnectedPeripherals: [CBPeripheral] = myCentral.retrieveConnectedPeripherals(withServices: [tagService.serviceUUID])
      if knownConnectedPeripherals.isEmpty == false {
        discoveredPeripherals = knownConnectedPeripherals
      }
    
      log.info("centralDelegate retrievingPeripherals is scanning for service: \(self.tagService.serviceUUID)")
      myCentral.scanForPeripherals(withServices: [tagService.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      
      // be careful about this call… I don't know how it works
      let peripheralToConnectTo = retrievePeripheral(uuid: uuidToConnectTo!)
      myCentral.connect(peripheralToConnectTo)
      // create a timeout for the last person discovered
      
    } else {
      log.info("centralDelegate retrievingPeripherals central is nil")
      return
    }
  }
  
  
  
  private func preparePeripheral(peripheral: CBPeripheralManager) {
    log.info("preparing peripheral")
    tagService.service.characteristics = [tagService.characteristic]
    peripheral.add(tagService.service)
    peripheral.startAdvertising(advertisementData)
    return
  }
  
  // View methods
  
  
  public func beginTagging() {
    
    // set a timer here for when the game begins
    
    updateTag(tagged: true)
  }
  
  
  public func beginRunning() {
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
      log.info("centralManagerDidUpdateState powered on")
//      switch tagged {
//      case false:
//        retrievePeripherals()
//      default:
//        log.info("Currently tagged; acting as peripheral")
//      }
//      log.info("centralManagerDidUpdateState scanning for services with CBUUID: \(self.tagService.serviceUUID)")
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
   Should assign the central variable to the returned central object
   */
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    log.info("centralDelegate is restoring state")
    /* just because the state has been restored does not mean that we were tagged just that the app has been reinitialized */
    guard let centraluuid = dict[CBCentralManagerOptionRestoreIdentifierKey] as? String else {
      log.info("centralDelegate willRestoreState no restoreIdentifier")
      return
    }
    log.info("centralDelegate willRestoreState restoring with UUID: \(centraluuid)")
    self.central = CBCentralManager(delegate: self, queue: .global(), options: [CBCentralManagerOptionRestoreIdentifierKey: centraluuid])
    centralUUID = UUID(uuidString: centraluuid)
    log.info("centralDelegate willRestoreState state restored")
  }
  
  
  /* this callback will be used for switching the states from scanning to advertising as a peripheral */
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    log.info("centralDelegate didConnect to peripheral: \(peripheral.identifier)")
    
    central.stopScan()
    log.info("centralDelegate didConnect stopped scanning")
    
    /* set the peripheral delegate to the current BLEManager */
    discoveredPeripherals?.append(peripheral)
    currentlyConnectedPeripheral?.delegate = self
    currentlyConnectedPeripheral?.discoverServices([tagService.serviceUUID])
  }
  
  
  
  /* TEST METHODS */
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    log.info("centralDelegate didDisconnectPeripheral from peripheral: \(peripheral.identifier)")
    currentlyConnectedPeripheral = nil
    retrievePeripherals()
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    log.info("centralDelegate didFailToConnect to peripheral: \(peripheral.identifier)")
    /* should deal with a failed connection appropriately */
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    log.info("centralDelegate didDiscover peripheral: \(peripheral.identifier)")
    
    if currentlyConnectedPeripheral == nil {
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


/*
 PERIPHERAL DELEGATE METHODS
 */

extension BLEManager: CBPeripheralDelegate {
  
  /* did discover the service that we wanted */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didDiscoverServices error while discovering services: \(error.localizedDescription)")
      return
    }
    log.info("peripheralDelegate didDiscoverServices discovered services for peripheral \(peripheral.identifier)")
    guard let peripheralServices = peripheral.services else {return}
    for service in peripheralServices where service.uuid == tagService.serviceUUID {
      peripheral.discoverCharacteristics([tagService.characteristicUUID], for: service)
    }
  }
  
  
  
  /* did discover the characteristics that we wanted as well and then we just wait for data to come in */
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
    if let error = error {
      log.info("peripheralDelegate didDiscoverCharactersticsFor error while discovering characteristics: \(error.localizedDescription)")
      return
    }
    guard let serviceCharacteristics = service.characteristics else { return }
    
    for characteristic in serviceCharacteristics where characteristic.uuid == tagService.characteristicUUID {
      log.info("peripheralDelegate didDiscoverCharactersticsFor discovered characteristic \(characteristic.uuid)")
      if let charData = characteristic.value {
        previousCharacteristicValue = String(data: charData, encoding: .utf8)
      } else {
        previousCharacteristicValue = nil
      }
      
      /*
       HERE: Write to the peripheral the UUID of the central here!
       */
      
//      var myPeripheralUUID: Data = Data()
//      withUnsafeBytes(of: peripheralUUID, {myPeripheralUUID.append(contentsOf: $0)})
      let myPeripheralUUID = Data((peripheralUUID?.uuidString.utf8)!)
      log.info("peripheralDelegate didDiscoverCharacteristicsFor writing bytes: \(myPeripheralUUID) to peripheral: \(peripheral.identifier)")
      
      numberOfWrites += 1
      let myString = String(data: myPeripheralUUID, encoding: .utf8)
      log.info("peripheralDelegate didDiscoverCharacteristicsFor writing value: \(myString ?? "No value")")
      peripheral.writeValue(myPeripheralUUID, for: characteristic, type: .withResponse)
      log.info("peripheralDelegate number of writes: \(self.numberOfWrites)")
      
      updateTag(tagged: true)
    }
    
    /*
     After writing, disconnect
     */
//    central?.stopScan()
//    currentlyConnectedPeripheral = nil
//    central?.scanForPeripherals(withServices: [TagService.serviceUUID])
  }
  
  
  
  /* this function only called when the withResponse option is enabled?? */
  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didWriteValueFor error while writing to characteristic: \(error)")
      return
    }
    log.info("peripheralDelegate didWriteValueFor succeeded")
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate didUpdateValueFor error updating characteristic value: \(error.localizedDescription)")
      return
    }
    
    let charData = characteristic.value
    let newValue = String(data: charData!, encoding: .utf8)!
    previousCharacteristicValue = newValue
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    log.info("peripheralDelegate didModifyServices")
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
      
    case CBManagerState.poweredOff :
      log.info("peripheralManagerDidUpdateState powered off")
      
      /*
       should remove services here and stop advertising
       */
      if peripheral.isAdvertising {
        peripheral.stopAdvertising()
      }
      peripheral.removeAllServices()
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
    log.info("peripheralManagerDelegate willRestoreState is restoring state")
    
    guard let peripheraluuid = dict[CBPeripheralManagerOptionRestoreIdentifierKey] as? String else {
      log.info("peripheralManagerDelegate willRestoreState no restoration identifier")
      return
    }
    log.info("peripheralManagerDelegate willRestoreState restoring peripheral with UUID: \(peripheraluuid)")
    self.peripheral = CBPeripheralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: peripheraluuid])
    peripheralUUID = UUID(uuidString: peripheraluuid)
    log.info("peripheralManagerDelegate willRestoreState state restored")
  }
  
  
  /* TEST METHODS */
  
  /* This callback can be used to transition and write the connected BLEManager's peripheral's uuid */
  /* on a write receive we then need to actually modify the characteristics value */
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
      
      peripheral.respond(to: request, withResult: .success)
      log.info("peripheralManagerDelegate didReceiveWrite with value: \(uuid)")
      uuidToConnectTo = UUID(uuidString: uuid)
      log.info("peripheralManagerDelegate didReceiveWrite uuidToConnectTo updated value to: \(self.uuidToConnectTo?.uuidString ?? "no value")")
      /* optional will need fixing */
      updateTag(tagged: false)
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
