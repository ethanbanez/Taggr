//
//  BLEPeripheral.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/6/23.
//

import Foundation
import CoreBluetooth
import os


/* This class is used when the device is acting as the peripheral
    aka the person who is tagged */

/* As a peripheral, tagged, the service you advertise is the tagged service */
class BLEPeripheral: NSObject, ObservableObject {
  private let log = Logger(subsystem: Subsystem.connectivity.description, category: "BLEPeripheral")
  var manager: CBPeripheralManager
  let uuid: String
  init(uuid: String) {
    self.uuid = uuid
    manager = CBPeripheralManager(delegate: nil, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: uuid])
    super.init()
    preparePerpipheral(uuidString: uuid)
    log.info("BLEPeripheral is initialized")
  }
  deinit {
    manager.stopAdvertising()
    log.info("BLEPeripheral is deinitializing")
  }
  
  /* adds the TagService to the peripheral
      the TagService always has the tag characteristic as
      the peripheral will always be the one who is currently tagged
   */
  public func preparePerpipheral(uuidString: String) {
//    var uuid = UUID(uuidString: uuidString)
    var tagService: TagService = TagService()
    manager.add(tagService.service)
  }
}
