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
  @Published var tagged: Bool
  
  /* we need to receive these objects from somewhere else… in the initializer? */
  var central: BLECentral
  var peripheral: BLEPeripheral
  
  /* reference to the currently connected peripherals of the central */
  var connectedPeripherals: [CBPeripheral]
  
  /* reference to the advertisement data of the peripheral */
  private var advertisementData: [String: Any]
  
  /* this is a reference to the uuid that, when the app is a tagger, to connect to */
  private var uuidToConnectTo: UUID?
  
  /* these are the uuids of the peripheral and central objects that it is managing */
  private var peripheralUUID: UUID
  private var centralUUID: UUID
  
  /* this is a reference to the tag service that all devices in this group have */
  private var tagService: TagService = TagService()
  
  /* initialization */
  init(central: BLECentral, peripheral: BLEPeripheral) {
    tagged = UserDefaults.standard.bool(forKey: "isTagged")
    self.central = central
    self.peripheral = peripheral
    
    self.centralUUID = UUID(uuidString: central.uuid)!
    self.peripheralUUID = UUID(uuidString: peripheral.uuid)!
    
    /* set up ad Data and service */
    var tagService = TagService()
    advertisementData = [CBAdvertisementDataServiceUUIDsKey: [tagService.service.uuid], CBAdvertisementDataLocalNameKey: peripheral.manager.description] as [String : Any]
    peripheral.manager.add(tagService.service)
    
    self.connectedPeripherals = central.manager.retrieveConnectedPeripherals(withServices: [tagService.service.uuid])
    
    super.init()
    self.central.manager.delegate = self
    self.peripheral.manager.delegate = self
    
    log.info("BLEManager is initialized")
  }
  
  /* deinitialization */
  deinit {
    central.manager.stopScan()
    peripheral.manager.stopAdvertising()
    log.info("BLEManager is deinitialized")
  }
  
  /* this function should be in its own file with other lambda functions */
  private func sendUUID(uuid: String) {
    /* send to lambda */
  }
  
  /* lambda function */
  private func retrieveUUID() -> UUID {
    var uuid = UUID().uuidString
    return UUID(uuidString: uuid)!
  }
  
  /* transitions from central to peripheral */
  private func transitionToTagger() {
    UserDefaults.standard.set(true, forKey: "isTagged")
    tagged = true
    central.manager.stopScan()
    peripheral.manager.startAdvertising(advertisementData)
    sendUUID(uuid: peripheral.uuid)
    log.info("BLEManager transitionToTagger as: \(self.peripheral.uuid)")
  }
  
  /* transition from peripheral to central */
  private func transitionToTagged() {
    UserDefaults.standard.set(false, forKey: "isTagged")
    tagged = false
    var peripheralUUID = retrieveUUID()
    peripheral.manager.stopAdvertising()
    central.manager.connect(central.manager.retrievePeripherals(withIdentifiers: [peripheralUUID])[0])    // this should work because there will only be one matching UUID
    log.info("BLEManager transitionToTagged, connecting to: \(peripheralUUID.uuidString)")
  }
  
}

/*
    centrals only need to scan for a specific device which is the NSUUID of the peripheral (tagged)
    peripheral advertise only when they are tagged
 */
extension BLEManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    /* when bluetooth is powered on then we can start scanning. But we want to only scan when we're not peripheral not just when we're on... */
    case CBManagerState.poweredOn :
      log.info("centralManagerDidUpdateState powered on")
      /* in this, once it is powered on, we need to connect to the peripheral in question */
      var uuidList: [UUID] = [UUID()]
      var searchPeripheral: [CBPeripheral] = self.central.manager.retrievePeripherals(withIdentifiers: uuidList)
      /* should check if anything was retrieved */
      self.central.manager.connect(searchPeripheral[0])
    case CBManagerState.poweredOff :
      log.info("centralManagerDidUpdateState powered off")
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
    
    /* this restoration key returns any peripherals that were connected to or pending connection to the central device */
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      log.info("Peripherals \(peripherals)")
      connectedPeripherals = peripherals
    }
    
    /* just because the state has been restored does not mean that we were tagged just that the app has been reinitialized */
  }
  
  /* we can store all known peripheral uuids in persistent storage, but what is the point because we need to be told the uuid anyways from lambda */
  
  /* this callback will be used for switching the states from scanning to advertising as a peripheral */
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    self.tagged = true
    /* central is equivalent the central that is managed by this class */
    
    /* write this objects peripheral UUID for the other peripheral to connect to after it transitions */
    var uuidData: Data = Data()
    withUnsafeBytes(of: peripheralUUID.uuid, {uuidData.append(contentsOf: $0)})
    
    /* writes this objects peripheral uuid to the tagService characteristic which is the same for all devices part of this group */
    var convertedCharacteristic: CBCharacteristic = self.tagService.characteristic
    peripheral.writeValue(uuidData, for: convertedCharacteristic, type: .withoutResponse)     // writes to characteristic without need to check for a response
    
    central.stopScan()
    self.peripheral.manager.startAdvertising(advertisementData)
    
    // now we send out, through lambda, the peripheral uuid which the others will collect. Can send out as string or as bytes
    sendUUID(uuid: peripheralUUID.uuidString)
  }
}


/* PERIPHERAL DELEGATE METHODS */

extension BLEManager: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    /* when bluetooth is powered on then we can start scanning. But we want to only scan when we're not peripheral not just when we're on... */
    case CBManagerState.poweredOn :
      log.info("peripheralManagerDidUpdateState powered on")
    case CBManagerState.poweredOff :
      log.info("peripheralManagerDidUpdateState powered off")
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
    log.info("BLEManager peripheralManager is restoring state")
    
    if let adData = dict[CBPeripheralManagerRestoredStateAdvertisementDataKey] as? [String: Any] {
        advertisementData = adData
    }
    
    if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
      self.tagService.service = services[0]     // there should only be one service anyways…
    }
    
  }
  
  /* This callback can be used to transition and write the connected BLEManager's peripheral's uuid */
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    /*
        Use this function to write the connected manager's peripherals uuid
        so that when this transitions from peripheral to central it has a uuid to connect to…
     */
    for request in requests {
      guard let requestValue = request.value, let uuid = String(data: requestValue, encoding: .utf8) else {
        continue
      }
      log.info("peripheralManager didReceiveWrite from central: \(uuid)")
      /* optional will need fixing */
      uuidToConnectTo = UUID(uuidString: uuid)!
    }
    transitionToTagger()    // transitions to being a central and a tagger no matter what
  }
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    log.info("peripheralManager started advertising")
  }
}
