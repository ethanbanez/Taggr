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
  
  @Published var currentPeripheral: CBPeripheral?
  
  // this is to show, when creating a group, who is queuing up to be in the group, hopefully I can make it readable names as to the devices that are joining...
  @Published var currentlyConnectedPeripherals: [UUID: String]?
  
  // if we are starting out with the group ready should be false until proven true
  @Published var ready: Bool = false
  
  @Published var tagServiceValues = [UserDefaults.standard.string(forKey: "TagServiceUUID"), UserDefaults.standard.string(forKey: "TagCharacteristicUUID")]
  
  var central: CBCentralManager?
  var peripheral: CBPeripheralManager?
  
  private var connectedPeripherals: [UUID: CBPeripheral]?
  
  private var readyPeripherals: [UUID: CBPeripheral]?
  
  // indicates whether this BLEGroup started the call to the other members
  var startedGroupCall: Bool?
  
  private var advertisementData: [String: Any]
  
  private var personalTagService: PersonalTagService
  
  private var groupService: GroupService = GroupService()
  private var service: CBMutableService
  
  private var transitionState: Bool?
  
  
  override init() {
    // I don't think we should set this on the outset… wait for the ui to tell us what to do
    service = groupService.service
    advertisementData = [CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
    
    // woah very cool. It initializes a new TagService only if it didn't exist in userdefaults so only the first time it exists but never again… can use this with the personal tag service which is created when it first exists but is never changed again!!
    let serviceUUID = CBUUID(string: UserDefaults.standard.string(forKey: "PersonalTagServiceUUID") ?? {
      let uuid = UUID().uuidString
      UserDefaults.standard.set(uuid, forKey: "PersonalTagServiceUUID")
      return uuid
    }())
    
    let characteristicUUID = CBUUID(string: UserDefaults.standard.string(forKey: "PersonalTagCharacteristicUUID") ??  {
      let uuid = UUID().uuidString
      UserDefaults.standard.set(uuid, forKey: "PersonalTagCharacteristicUUID")
      return uuid
    }())
    
    log.info("initializing BLEGroup")
    personalTagService = PersonalTagService(serviceuuid: serviceUUID, characteristicuuid: characteristicUUID)
    
    super.init()
  }
  
  
  func destroyGroupSession() {
    startedGroupCall = nil
    ready = false
    if central?.isScanning ?? false && peripheral?.isAdvertising ?? false {
      log.info("destroying group session")
      central?.stopScan()
      for peripheral in central!.retrieveConnectedPeripherals(withServices: [groupService.serviceUUID]) {
        central?.cancelPeripheralConnection(peripheral)
        connectedPeripherals?.removeValue(forKey: peripheral.identifier)
        currentlyConnectedPeripherals?.removeValue(forKey: peripheral.identifier)
      }
      
      peripheral?.removeAllServices()
      peripheral?.stopAdvertising()
    }
  }
  
  
  // peripherals only join
  func joinGroup() {
    log.info("starting group search")
    startedGroupCall = false
    
    service.characteristics = [groupService.tagCharacteristicCharacteristic, groupService.tagServiceCharacteristic, groupService.readyCharacteristic, groupService.readyToTagCharacteristic]
    peripheral?.add(service)
    peripheral?.startAdvertising(advertisementData)
  }
  
  
  // centrals only create
  func createGroup() {
    log.info("starting group call")
    startedGroupCall = true
    ready = true
    
    central?.scanForPeripherals(withServices: [service.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    log.info("scanning for \(self.service.uuid.uuidString)")
    
    // add personal tag service to self as self is the group creator and therefore the service is this
    BLEManager.shared.tagService.serviceUUID = personalTagService.serviceUUID
    BLEManager.shared.tagService.characteristicUUID = personalTagService.characteristicUUID
  }
}


extension BLEGroup: CBCentralManagerDelegate {
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    log.info("central didUpdateState")
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
    @unknown default:
      log.error("unrecognized state")
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    log.info("discovered peripheral: \(peripheral.identifier)")
    currentPeripheral = peripheral
    connectedPeripherals?[currentPeripheral!.identifier] = currentPeripheral
    currentPeripheral?.delegate = self
    
    // rssi indicates signal strength
    if RSSI.intValue >= -80 {
      let alreadyConnectedPeripherals: [CBPeripheral] = central.retrieveConnectedPeripherals(withServices: [service.uuid])
      // only connect if this central has not connected before
      if !alreadyConnectedPeripherals.contains(where: {$0.identifier == currentPeripheral?.identifier}) {
        central.connect(currentPeripheral!)
        log.info("not connected before")
      } else {
        log.info("already connected before")
      }
    } else {
      log.info("peripheral too far away; rssi: \(RSSI.intValue)")
      connectedPeripherals?.removeValue(forKey: currentPeripheral!.identifier)
    }
  }
  
  
  /*
   if the central successfully connected then, if the central is the one starting the session, it should write it's new TagService uuids to the connected
   peripheral. Otherwise, connecting is enough I believe…
   */
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    log.info("central didConnect successful")
    
    // if this central started the group call then we want to disseminate the TagService
    // along with disseminating to others we should set our own TagService to our personal TagService
    currentlyConnectedPeripherals?[peripheral.identifier] = peripheral.name ?? "Unnamed device"
    currentPeripheral!.discoverServices([service.uuid])
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    
    currentPeripheral = nil
    currentlyConnectedPeripherals?.removeValue(forKey: peripheral.identifier)
    connectedPeripherals?.removeValue(forKey: peripheral.identifier)
    
    if let error = error {
      log.info("central error while disconnecting from peripheral: \(error.localizedDescription)")
      return
    }
    log.info("central disconnected from peripheral: \(peripheral.identifier)")
  }
}


extension BLEGroup: CBPeripheralDelegate {
  
  // we read the rssi to test the connection
  func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    if let error = error {
      log.info("peripheral error reading RSSI value: \(error.localizedDescription)")
      return
    }
    log.info("peripheral RSSI value successfully read")
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      log.info("peripheral error in discover services: \(error.localizedDescription)")
      return
    }
    
    guard let peripheralServices = peripheral.services else {return}
    
    // at this point there should only be one service but just in case, check
    for service in peripheralServices where service.uuid == self.service.uuid {
      // discover both of the characteristics that the searching peripheral will have
      peripheral.discoverCharacteristics([groupService.tagServiceUUID, groupService.tagCharacteristicUUID, groupService.readyCharacteristicUUID, groupService.readyToTagCharacteristicUUID], for: service)
    }
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let error = error {
      log.info("peripheral error discvoring characteristics: \(error.localizedDescription)")
    }
    guard let groupCharacteristics = service.characteristics else {
      log.info("peripheral no characteristics for service \(service.uuid)")
      return
    }
    
    // writing tag service UUID
    for tagServiceCharacteristic in groupCharacteristics where tagServiceCharacteristic.uuid == groupService.tagServiceUUID {
      let myTagServiceUUID = Data(personalTagService.serviceUUID.uuidString.utf8)
      peripheral.writeValue(myTagServiceUUID, for: tagServiceCharacteristic, type: .withResponse)
      log.info("peripheral writing to TagService characteristic")
    }
    
    // writing tag characteristic UUID
    for tagCharacteristicCharacteristic in groupCharacteristics where tagCharacteristicCharacteristic.uuid == groupService.tagCharacteristicUUID {
      let myTagCharacteristicUUID = Data(personalTagService.characteristicUUID.uuidString.utf8)
      peripheral.writeValue(myTagCharacteristicUUID, for: tagCharacteristicCharacteristic, type: .withResponse)
      log.info("peripheral writing to TagCharacteristic characteristic")
    }
    
    // characteristic to notify when ready
    for readyCharacteristic in groupCharacteristics where readyCharacteristic.uuid == groupService.readyCharacteristicUUID {
      peripheral.setNotifyValue(true, for: readyCharacteristic)
    }
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    
    if let error = error {
      log.info("peripheral error while writing to characteristic: \(characteristic.uuid) with error: \(error.localizedDescription)")
      return
    }
    
    if characteristic.uuid == groupService.tagServiceUUID {
      // therefore writing to the TagService
      log.info("peripheral successfully written to TagService characteristic")
      return
    }
    
    if characteristic.uuid == groupService.tagCharacteristicUUID {
      log.info("peripheral successfully written to TagCharacteristic characteristic")
      return
    }
    
    if characteristic.uuid == groupService.readyCharacteristicUUID {
      log.info("tagger has been set")
    }
    
    
    // the central (group starter) will transition to tagging phase. After all peripherals have been written to
    if characteristic.uuid == groupService.readyToTagCharacteristicUUID {
      log.info("all peripherals have been written to and now we may transition as well")
      
      if self.transitionState! == true {
        BLEManager.shared.beginTagging()
      } else {
        BLEManager.shared.beginRunning()
      }
    }
  }
  
  
  
  // we get notifications here for whether a peripheral is ready or not
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let error = error {
      log.info("error in updating value for ready characteristic: \(error.localizedDescription)")
      return
    }
    
    
    if characteristic.uuid == groupService.readyCharacteristicUUID {
      
      log.info("received updated value for ready characteristic")
      
      let val = [UInt8](characteristic.value!)
      if val[0] != 0 {
        
        readyPeripherals?[peripheral.identifier] = peripheral
        if readyPeripherals?.count == connectedPeripherals?.count {
          
          // theoretically inside this should only be called once
          log.info("all peripherals are ready")
          
          let connectedPeripherals = central!.retrieveConnectedPeripherals(withServices: [groupService.serviceUUID])
          
          guard let p = connectedPeripherals.first(where: {$0.identifier == peripheral.identifier}) else {
            log.info("no mathcing connected peripherals")
            return
          }
          guard let peripheralServices = p.services else {
            log.info("no services")
            return
          }
          guard let service = peripheralServices.first(where: {$0.uuid == self.service.uuid}) else {
            log.info("no matching services")
            return
          }
          guard let groupCharacteristics = service.characteristics else {
            log.info("no characteristics")
            return
          }
          guard let readyToTagCharacteristic = groupCharacteristics.first(where: {$0.uuid == groupService.readyToTagCharacteristicUUID}) else {
            log.info("no matching characteristics")
            return
          }
          
          let peripheralIndex = Int.random(in: 0...connectedPeripherals.count)
          
          log.info("index of chosen peripheral ==> \(peripheralIndex)")
          
          
          // write to peripherals first before transitioning
          
          // if peripheralIndex == the count then that means it should be the central starting the call who is it
          if peripheralIndex == connectedPeripherals.count {
            for connectedPeripheral in connectedPeripherals {
              
              // for all the connected peripherals; tell them they are not it
              // readyToTagCharacteristic will have already been discovered
              connectedPeripheral.writeValue(Data([0x0]), for: readyToTagCharacteristic, type: .withResponse)
            }
            
            transitionState = true
            
          } else {
            transitionState = false
            
            // it's someone connected to us
            let taggedPeripheral = connectedPeripherals[peripheralIndex]
            taggedPeripheral.writeValue(Data([0x1]), for: readyToTagCharacteristic, type: .withResponse)
            for connectedPeripheral in connectedPeripherals where connectedPeripheral.identifier != taggedPeripheral.identifier {
              // for all the other connected peripherals; tell them they are not it
              connectedPeripheral.writeValue(Data([0x0]), for: readyToTagCharacteristic, type: .withResponse)
            }
          }
          
        } else {
          log.info("peripheral is ready")
        }
      } else {
        log.info("peripheral is not ready")
      }
    }
    
    // this means we've discovered the characteristic and that we can now write to the characteristic
    if characteristic.uuid == groupService.readyToTagCharacteristicUUID {
      log.info("here is where we would write to the peripheral that was chosen")
    }
    
  }
  
  
  
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    for service in invalidatedServices where service.uuid == groupService.service.uuid {
      log.info("received all tag services")
    }
  }
  
}



extension BLEGroup: CBPeripheralManagerDelegate {
  
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    log.info("peripheral manager didUpdateState")
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
      if peripheral.isAdvertising {
        peripheral.stopAdvertising()
      }
      peripheral.removeAllServices()
    case .poweredOn:
      log.info("poweredOn state")
      /* Never scan for the same peripheral. Once a peripheral has been discovered then it will be in the knownPeripherals array and the work is done */
    @unknown default:
      log.error("unrecognized state")
    }
  }
  
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    if let error = error {
      log.info("peripheral manager error adding service: \(error.localizedDescription)")
      return
    }
    log.info("peripheral manager added service: \(service.uuid)")
  }
  
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      log.info("peripheral manager error advertising: \(error.localizedDescription)")
      return
    }
    log.info("started advertising service with num of characteristics: \(self.service.characteristics?.count.description ?? "nil" )")
  }
  
  /*
   writes to both the TagService and TagCharacteristic characteristics of the GroupService
   should signal after processing that this device is ready as the TagService has been configured
   */
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    
    for request in requests {
      guard let requestValue = request.value else {
        log.info("peripheral manager no value in request")
        peripheral.respond(to: request, withResult: .unlikelyError)
        return
      }
      
      
      var tagService: UUID?
      var tagCharacteristic: UUID?
      
      
      // writes the service to the BLEManager (tag manager)
      if request.characteristic.uuid == groupService.tagServiceUUID {
        log.info("peripheral manager received write request for uuid: \(request.characteristic.uuid.uuidString)")
        let uuidString = String(data: requestValue, encoding: .utf8)
        log.info("sending tag service to bleManager: \(uuidString!)")
        tagService = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
        BLEManager.shared.tagService.serviceUUID = CBUUID(nsuuid: tagService!)
        if BLEManager.shared.tagService.tagServiceReady() {
          log.info("tag service is fully configured and ready for tagging")
          ready = true
          return
        }
      }
      
      
      if request.characteristic.uuid == groupService.tagCharacteristicUUID {
        log.info("peripheral manager received write request for uuid: \(request.characteristic.uuid.uuidString)")
        let uuidString = String(data: requestValue, encoding: .utf8)
        log.info("sending tag characteristic to bleManager: \(uuidString!)")
        tagCharacteristic = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
        BLEManager.shared.tagService.characteristicUUID = CBUUID(nsuuid: tagCharacteristic!)
        if BLEManager.shared.tagService.tagServiceReady() {
          log.info("tag service is fully configured and ready for tagging")
          ready = true
          return
        }
      }
      
      
      // this is where the peripherals will disconnect first
      if request.characteristic.uuid == groupService.readyToTagCharacteristicUUID {
        log.info("being told whether we are starting out tagged or not")
        
        // the response from the central should be to then transition as well
        peripheral.respond(to: request, withResult: .success)
        
        let tagged = [UInt8](requestValue)
        if tagged[0] == 1 {
          BLEManager.shared.beginTagging()
        } else {
          BLEManager.shared.beginRunning()
        }
      }
    }
  }
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    log.info("central has subscribed to the ready characteristic")
    
    /* maybe we need to loop for as long as ready is false? */
    while !ready {
      peripheral.updateValue(Data([0x0]), for: groupService.readyCharacteristic, onSubscribedCentrals: [central])
      return
    }
    log.info("tag service is ready -> sending signal")
    peripheral.updateValue(Data([0x1]), for: groupService.readyCharacteristic, onSubscribedCentrals: [central])
  }
  
  
  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    log.info("peripheral manager is ready to update subsribers")
  }
  
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    log.info("received read request for: \(request.characteristic.uuid.uuidString)")
  }
  
}
