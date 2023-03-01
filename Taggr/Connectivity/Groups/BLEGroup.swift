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
    //    log.info("personal tag service initialized as \(serviceUUID.uuidString)")
    //    log.info("personal tag characteristic initialized as \(characteristicUUID.uuidString)")
    
    // if the personalTagService is already initialized here with the right uuids from either the past or for the first time and it's not set anywhere else do I need the didSet functionality? I don't think so…
    personalTagService = PersonalTagService(serviceuuid: serviceUUID, characteristicuuid: characteristicUUID)
    
    super.init()
  }
  
  
  func destroyGroupSession() {
    // resets group call boolean
    //    startedGroupCall = nil
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
  
  
  func joinGroup() {
    log.info("starting group search")
    startedGroupCall = false
    
    service.characteristics = [groupService.tagCharacteristicCharacteristic, groupService.tagServiceCharacteristic, groupService.readyCharacteristic, groupService.readyToTagCharacteristic]
    peripheral?.add(service)
    peripheral?.startAdvertising(advertisementData)
    
    central?.scanForPeripherals(withServices: [service.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    log.info("scanning for \(self.service.uuid.uuidString)")
  }
  
  
  func createGroup() {
    log.info("starting group call")
    startedGroupCall = true
    ready = true
    
    peripheral?.add(service)
    peripheral?.startAdvertising(advertisementData)
    
    central?.scanForPeripherals(withServices: [service.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    log.info("scanning for \(self.service.uuid.uuidString)")
    
    // add personal tag service to self as self is the group creator and therefore the service is this
    BLEManager.shared.tagService.serviceUUID = personalTagService.serviceUUID
    BLEManager.shared.tagService.characteristicUUID = personalTagService.characteristicUUID
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
      //      central.scanForPeripherals(withServices: [GroupService.service.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    @unknown default:
      log.error("unrecognized state")
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    log.info("discovered peripheral: \(peripheral.identifier)")
    currentPeripheral = peripheral
    connectedPeripherals?[currentPeripheral!.identifier] = currentPeripheral
    currentPeripheral?.delegate = self
    // rssi between -50 and -30 is a strong connection, hopefully indicating they are close enough
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
    log.info("centralDelegate didConnect successful")
    
    // if this central started the group call then we want to disseminate the TagService
    // along with disseminating to others we should set our own TagService to our personal TagService
    currentlyConnectedPeripherals?[peripheral.identifier] = peripheral.name ?? "Unnamed device"
    
    if startedGroupCall! {
      currentPeripheral!.discoverServices([service.uuid])
      
      // add personal tag service to self as self is the group creator and therefore the service is this
      //      BLEManager.shared.tagService.serviceUUID = personalTagService.serviceUUID
      //      BLEManager.shared.tagService.characteristicUUID = personalTagService.characteristicUUID
    } else {
      // if the device did not start the group call and yet is here and still searching then this is where we can stop because now we've connected. We may need to go farther to join the knownPeripherals array
      
      // so far as I can understand there is nothing to be done for a peripheral that has connected to a fellow searching device
      log.info("staying connected but no data is needed")
    }
  }
  
  
  
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    
    currentPeripheral = nil
    currentlyConnectedPeripherals?.removeValue(forKey: peripheral.identifier)
    connectedPeripherals?.removeValue(forKey: peripheral.identifier)
    
    if let error = error {
      log.info("centralDelegate error while disconnecting from peripheral: \(error.localizedDescription)")
      return
    }
    log.info("centralDelegate disconnected from peripheral: \(peripheral.identifier)")
  }
  
  
  
  //  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
  //    log.info("BLEGroup central is restoring state")
  //  }
  
}


// once we connect to a peripheral this will be called and the same device will get the peripheral callbacks

/*
 these callbacks will be called by searching searching peripherals
 maybe the best place for these callbacks should be on the peripheral manager side… experiment
 */
extension BLEGroup: CBPeripheralDelegate {
  
  // we read the rssi to test the connection
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
    for service in peripheralServices where service.uuid == self.service.uuid {
      // discover both of the characteristics that the searching peripheral will have
      peripheral.discoverCharacteristics([groupService.tagServiceUUID, groupService.tagCharacteristicUUID, groupService.readyCharacteristicUUID], for: service)
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
    log.info("tagService configured? : \(BLEManager.shared.tagService.configured.description)")
//    if (BLEManager.shared.tagService.configured != true) {
      
      for tagServiceCharacteristic in groupCharacteristics where tagServiceCharacteristic.uuid == groupService.tagServiceUUID {
        // this is where we write to the characteristic of the searching peripherals
        /* Should have two characteristics to distinguish between the two uuids coming through */
        let myTagServiceUUID = Data(personalTagService.serviceUUID.uuidString.utf8)
        peripheral.writeValue(myTagServiceUUID, for: tagServiceCharacteristic, type: .withResponse)
        log.info("peripheralDelegate writing to TagService characteristic")
      }
      
      for tagCharacteristicCharacteristic in groupCharacteristics where tagCharacteristicCharacteristic.uuid == groupService.tagCharacteristicUUID {
        // this is where we write to the characteristic of the searching peripherals
        /* Should have two characteristics to distinguish between the two uuids coming through */
        let myTagCharacteristicUUID = Data(personalTagService.characteristicUUID.uuidString.utf8)
        peripheral.writeValue(myTagCharacteristicUUID, for: tagCharacteristicCharacteristic, type: .withResponse)
        log.info("peripheralDelegate writing to TagCharacteristic characteristic")
      }
//    }
    
    for readyCharacteristic in groupCharacteristics where readyCharacteristic.uuid == groupService.readyCharacteristicUUID {
      //      var connectedPeripherals = central?.retrieveConnectedPeripherals(withServices: [groupService.serviceUUID])
      //      var peripheralIndex = Int.random(in: 0...connectedPeripherals!.count)
      //      var taggedPeripheral = connectedPeripherals?[peripheralIndex]
      //
      //      if peripheralIndex > connectedPeripherals!.count {
      //
      //      } else {
      //
      //      }
      //
      //      if peripheral.identifier == taggedPeripheral?.identifier {
      //        peripheral.writeValue(Data([1]), for: readyCharacteristic, type: .withResponse)
      //      } else {
      //        peripheral.writeValue(Data([0]), for: readyCharacteristic, type: .withResponse)
      //      }
      peripheral.setNotifyValue(true, for: readyCharacteristic)
    }
    
    // if we have discovered this then the peripherals are all ready and we need to choose the peripheral to be tagged first
    for readyToTagCharacteristic in groupCharacteristics where readyToTagCharacteristic.uuid == groupService.readyToTagCharacteristicUUID {
      peripheral.setNotifyValue(true, for: readyToTagCharacteristic)
    }
    
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    
    if let error = error {
      log.info("peripheralDelegate error while writing to characteristic: \(characteristic.uuid) with error: \(error.localizedDescription)")
      return
    }
    
    if characteristic.uuid == groupService.tagServiceUUID {
      // therefore writing to the TagService
      log.info("peripheralDelegate successfully written to TagService characteristic")
      return
    }
    
    if characteristic.uuid == groupService.tagCharacteristicUUID {
      log.info("peripheralDelegate successfully written to TagCharacteristic characteristic")
      return
    }
    
    if characteristic.uuid == groupService.readyCharacteristicUUID {
      log.info("tagger has been set")
    }
  }
  
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    log.info("getting notifications for: \(characteristic.uuid.uuidString)")
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
          log.info("all peripherals are ready")
          log.info("received the clear to tag everyone")
          
          // discover the characteristic to write which peripheral will be tagged
          for p in central!.retrieveConnectedPeripherals(withServices: [groupService.serviceUUID]) {
            guard let peripheralServices = p.services else {return}
            for service in peripheralServices where service.uuid == self.service.uuid {
              
              // haven't updated the peripherals to have this characteristicUUID
              // we've already discovered this characteristic we just need to write to it
              // once we're actually ready… then we write
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
      log.info("peripheralManagerDelegate error adding service: \(error.localizedDescription)")
      return
    }
    log.info("peripheralManagerDelegate added service: \(service.uuid)")
  }
  
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    if let error = error {
      log.info("peripheralManagerDelegate error advertising: \(error.localizedDescription)")
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
        log.info("peripheralManagerDelegate no value in request")
        peripheral.respond(to: request, withResult: .unlikelyError)
        return
      }
      
      
      var tagService: UUID?
      var tagCharacteristic: UUID?
      
      
      if request.characteristic.uuid == groupService.tagServiceUUID {
        log.info("peripheralManagerDelegate received write request for uuid: \(request.characteristic.uuid.uuidString)")
        let uuidString = String(data: requestValue, encoding: .utf8)
        log.info("sending tag service to bleManager: \(uuidString!)")
        tagService = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
        BLEManager.shared.tagService.serviceUUID = CBUUID(nsuuid: tagService!)
        if BLEManager.shared.tagService.tagServiceReady() {
          log.info("tag service is fully configured and ready for tagging")
          
          // the following should remove and add a service allowing the central to discover the new characteristic… it may have to start scanning again though…
          //          service.characteristics?.append(groupService.readyCharacteristic)
          //          self.peripheral?.removeAllServices()
          //          self.peripheral?.add(service)
          
          ready = true
          return
        }
      }
      
      
      if request.characteristic.uuid == groupService.tagCharacteristicUUID {
        log.info("peripheralManagerDelegate received write request for uuid: \(request.characteristic.uuid.uuidString)")
        let uuidString = String(data: requestValue, encoding: .utf8)
        log.info("sending tag characteristic bleManager: \(uuidString!)")
        tagCharacteristic = UUID(uuidString: uuidString!)!
        peripheral.respond(to: request, withResult: .success)
        BLEManager.shared.tagService.characteristicUUID = CBUUID(nsuuid: tagCharacteristic!)
        if BLEManager.shared.tagService.tagServiceReady() {
          log.info("tag service is fully configured and ready for tagging")
          
          //          log.info("adding ready characteristic and restarting service")
          //          service.characteristics?.append(groupService.readyCharacteristic)
          //
          //          // removing the service doesn't do anything to fix the problem of leaving the ui…
          //          self.peripheral?.removeAllServices()
          //          self.peripheral?.add(service)
          ready = true
          return
        }
      }
      
      
      //      if request.characteristic.uuid == groupService.readyCharacteristicUUID {
      //        log.info("receiving tag assignment")
      //        var tagged = [UInt8](requestValue)
      //        if tagged[0] == 1 {
      //          BLEManager.shared.beginTagging()
      //        } else {
      //          BLEManager.shared.beginRunning()
      //        }
      //      }
      /*
       here we should instantiate the TagService for the device…
       
       By writing to the manager of the device, anytime someone writes to this device the TagService is updated on the BLEManager TagService side which allows it to tag the right person.
       This peripheral manager function is from the side of the device who did not start the group and therefore does not know, or have, the relevant uuids for the TagService and so this disseminates it to the devices BLEManager
       After this has been accomplished we should wait for the game to start and the first device to be chosen to be the tagger in which we will scan for the service that was sent here and connect to the uuid, belonging to a specific CBPeripheral, that will be disseminated when that person is chosen
       All of the group set up needs to be done in person with people close enough to each other for it to work.
       */
    }
    
    
  }
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    log.info("central has subscribed to the ready characteristic")
    
    /* maybe we need to loop for as long as ready is false? */
    while !ready {
      peripheral.updateValue(Data([0x0]), for: groupService.readyCharacteristic, onSubscribedCentrals: [central])
      return
    }
    log.info("tag service is ready")
    peripheral.updateValue(Data([0x1]), for: groupService.readyCharacteristic, onSubscribedCentrals: [central])
  }
  
  
  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    log.info("peripheral manager is ready to update subsribers")
  }
  
  
  
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    log.info("received read request for: \(request.characteristic.uuid.uuidString)")
  }
  
  
  //  func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
  //    log.info("BLEGroup peripheral is restoring state")
  //  }
}
