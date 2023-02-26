//
//  Group.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/25/23.
//

import Foundation
import CoreBluetooth
import os

/*
 Create functions to initialize a group
 */

/*
 To create a group all the centrals and peripherals of each phone needs to have connected to each other
 therefore; to create a group, as a once a time thing there needs to be a default variable
 */
// initializes scanning for possible members

/* assume that, if this object has been allocated, then it is trying to find a group */


class BLEGroup: NSObject, ObservableObject {
  
  static let shared = BLEGroup()
  
  private let log = Logger(subsystem: Subsystem.group.description, category: "BLEGroup")
  
  var central: CBCentralManager?
  var peripheal: CBPeripheralManager?
  
  // indicates whether this BLEGroup started the call to the other members
  var startedGroupCall: Bool
  
  var advertisementData: [String: Any]
  
  var personalTagService: PersonalTagService
  

  override init() {
    startedGroupCall = defaults.bool(forKey: "inGroup")
    advertisementData = [CBAdvertisementDataServiceUUIDsKey: [GroupService.serviceUUID]]
    
    // woah very cool. It initializes a new TagService only if it didn't exist in userdefaults so only the first time it exists but never again… can use this with the personal tag service which is created when it first exists but is never changed again!!
    let serviceUUID = CBUUID(string: defaults.string(forKey: "PersonalTagServiceUUID") ?? {
      let uuid = UUID().uuidString
      defaults.set(uuid, forKey: "PersonalTagServiceUUID")
      return uuid
    }())
    
    let characteristicUUID = CBUUID(string: defaults.string(forKey: "PersonalTagCharacteristicUUID") ??  {
      let uuid = UUID().uuidString
      defaults.set(uuid, forKey: "PersonalTagCharacteristicUUID")
      return uuid
    }())
    
    personalTagService = PersonalTagService(serviceuuid: serviceUUID, characteristicuuid: characteristicUUID)
  }
}


extension BLEGroup: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    log.info("centralDelegate didUpdateState")
    switch central.state {
    case .unknown:
      log.info("unknown state")
    case .resetting:
      log.info("resetting state")
    case .unsupported:
      log.info("unsupported state")
    case .unauthorized:
      log.info("unauthorized state")
    case .poweredOff:
      log.info("poweredOff state")
    case .poweredOn:
      log.info("poweredOn state")
      /* Never scan for the same peripheral. Once a peripheral has been discovered then it will be in the knownPeripherals array and the work is done */
      central.scanForPeripherals(withServices: [GroupService.service.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    @unknown default:
      log.error("unrecognized state")
    }
  }
 
  
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    peripheral.delegate = self
    // rssi between -50 and -30 is a strong connection, hopefully indicating they are close enough
    if RSSI.intValue >= -50 {
      let alredyConnectedPeripherals: [CBPeripheral] = central.retrieveConnectedPeripherals(withServices: [GroupService.serviceUUID])
      
      // only connect if this central has not connected before
      if !alredyConnectedPeripherals.contains(where: {$0.identifier == peripheral.identifier}) {
        central.connect(peripheral)
      }
    }
  }
  
  
  /*
   if the central successfully connected then, if the central is the one starting the session, it should write it's new TagService uuids to the connected
   peripheral. Otherwise, connecting is enough I believe…
   */
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    log.info("centralDelegate didConnect successful")
    // if this central started the group call then we want to disseminate the TagService
    // along with disseminating to others we should set our own TagService to our personal TagService
    if startedGroupCall {
      peripheral.discoverServices([GroupService.service.uuid])
      BLEManager.shared.tagService.serviceUUID = personalTagService.serviceUUID
      BLEManager.shared.tagService.characteristicUUID = personalTagService.characteristicUUID
    }
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if let error = error {
      log.info("centralDelegate error while disconnecting from peripheral: \(error.localizedDescription)")
      return
    }
    log.info("centralDelegate disconnected from peripheral: \(peripheral.identifier)")
  }
  
}


extension BLEGroup: CBPeripheralDelegate {
  
  func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate error reading RSSI value: \(error.localizedDescription)")
      return
    }
    log.info("peripheralDelegate RSSI value successfully read")
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      log.info("peripheralDelegate error in discover services: \(error.localizedDescription)")
      return
    }
    
    guard let peripheralServices = peripheral.services else {return}
    
    // at this point there should only be one service but just in case, check
    for service in peripheralServices where service.uuid == GroupService.serviceUUID {
      peripheral.discoverCharacteristics([GroupService.tagServiceUUID, GroupService.tagCharacteristicUUID], for: service)
    }
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let error = error {
      log.info("peripheralDelegate error discvoring characteristics: \(error.localizedDescription)")
    }
    guard let groupCharacteristics = service.characteristics else {
      log.info("peripheralDelegate no characteristics for service \(service.uuid)")
      return
    }
    
    /*
     These two loops are where personal tag services are written. We need to write personal tag services. Not the general tag services which is what is happening here
     */
    // look for the required characteristic
    for tagServiceCharacteristic in groupCharacteristics where tagServiceCharacteristic.uuid == GroupService.tagServiceUUID {
      // this is where we write to the characteristic of the searching peripherals
      /* Should have two characteristics to distinguish between the two uuids coming through */
      var myTagServiceUUID = Data(personalTagService.serviceUUID.uuidString.utf8)
      peripheral.writeValue(myTagServiceUUID, for: tagServiceCharacteristic, type: .withResponse)
      log.info("peripheralDelegate writing to TagService characteristic")
    }
    
    for tagCharacteristicCharacteristic in groupCharacteristics where tagCharacteristicCharacteristic.uuid == GroupService.tagCharacteristicUUID {
      // this is where we write to the characteristic of the searching peripherals
      /* Should have two characteristics to distinguish between the two uuids coming through */
      var myTagCharacteristicUUID = Data(personalTagService.characteristicUUID.uuidString.utf8)
      peripheral.writeValue(myTagCharacteristicUUID, for: tagCharacteristicCharacteristic, type: .withResponse)
      log.info("peripheralDelegate writing to TagCharacteristic characteristic")
    }
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    
    if let error = error {
      log.info("peripheralDelegate error while writing to characteristic: \(characteristic.uuid) with error: \(error.localizedDescription)")
      return
    }
    
    if characteristic.uuid == GroupService.tagServiceUUID {
      // therefore writing to the TagService
      log.info("peripheralDelegate successfully written to TagService characteristic")
      return
    }
    
    if characteristic.uuid == GroupService.tagCharacteristicUUID {
      log.info("peripheralDelegate successfully written to TagCharacteristic characteristic")
      return
    }
  }
  
}



extension BLEGroup: CBPeripheralManagerDelegate {
  
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    log.info("peripheralManagerDelegate didUpdateState")
    switch peripheral.state {
    case .unknown:
      log.info("unknown state")
    case .resetting:
      log.info("resetting state")
    case .unsupported:
      log.info("unsupported state")
    case .unauthorized:
      log.info("unauthorized state")
    case .poweredOff:
      log.info("poweredOff state")
      peripheral.removeAllServices()
      peripheral.stopAdvertising()
    case .poweredOn:
      log.info("poweredOn state")
      /* Never scan for the same peripheral. Once a peripheral has been discovered then it will be in the knownPeripherals array and the work is done */
      if !startedGroupCall {
        GroupService.service.characteristics = [GroupService.tagCharacteristicCharacteristic, GroupService.tagServiceCharacteristic]
        peripheral.add(GroupService.service)
      } else {
        peripheral.add(GroupService.service)
      }
      peripheral.startAdvertising(advertisementData)
      
      log.info("peripheralManagerDelegate started advertising")
    @unknown default:
      log.error("unrecognized state")
    }
  }
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    if let error = error {
      log.info("peripheralManagerDelegate error adding service: \(error.localizedDescription)")
      return
    }
    log.info("peripheralManagerDelegate added service: \(service.uuid)")
  }
  
  
  /*
   writes to both the TagService and TagCharacteristic characteristics of the GroupService
   */
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    
    for request in requests {
      guard let requestValue = request.value else {
        log.info("peripheralManagerDelegate no value in request")
        peripheral.respond(to: request, withResult: .unlikelyError)
        return
      }
      
      var tagService: UUID?
      var tagCharacteristic: UUID?
      
      if request.characteristic.uuid == GroupService.tagServiceUUID {
        let uuidString = String(data: requestValue, encoding: .utf8)
        tagService = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
      }
      
      if request.characteristic.uuid == GroupService.tagCharacteristicUUID {
        let uuidString = String(data: requestValue, encoding: .utf8)
        tagCharacteristic = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
      }
      
      /*
       here we should instantiate the TagService for the device…
       
       By writing to the manager of the device, anytime someone writes to this device the TagService is updated on the BLEManager TagService side which allows it to tag the right person.
       This peripheral manager function is from the side of the device who did not start the group and therefore does not know, or have, the relevant uuids for the TagService and so this disseminates it to the devices BLEManager
       After this has been accomplished we should wait for the game to start and the first device to be chosen to be the tagger in which we will scan for the service that was sent here and connect to the uuid, belonging to a specific CBPeripheral, that will be disseminated when that person is chosen
       All of the group set up needs to be done in person with people close enough to each other for it to work.
       */
      BLEManager.shared.tagService.serviceUUID = CBUUID(nsuuid: tagService!)
      BLEManager.shared.tagService.characteristicUUID = CBUUID(nsuuid: tagCharacteristic!)
    }
  }
  
}
