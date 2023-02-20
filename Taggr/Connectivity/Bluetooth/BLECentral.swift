//
//  BLECentral.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/6/23.
//

import Foundation
import CoreBluetooth
import UIKit
import os

/* Different CBManagerState states:
    poweredOff
    poweredOn
    resetting
 */

class BLECentral: NSObject, ObservableObject {
  let log = Logger(subsystem: Subsystem.connectivity.description, category: "BLECentral")
  var manager: CBCentralManager
  let uuid: String
  init(uuid: String) {
    self.uuid = uuid
    /* Possibly add other options? Like a list of peripherals to look out for? */
    manager = CBCentralManager(delegate: nil, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: uuid])
    super.init()
    log.info("BLECentral is initialized")
    
    /* do we need these options? */
//    manager.registerForConnectionEvents(options: [CBConnectionEventMatchingOption(rawValue: CBConnectPeripheralOptionNotifyOnNotificationKey): true, CBConnectionEventMatchingOption(rawValue: CBConnectPeripheralOptionNotifyOnConnectionKey): true])
  }
  /* make sure deinit is only called after the background process is totally cut off */
  deinit {
    /* when the app is cut off ideally we want to connect to the advertising peripheral which is `*/
    manager.stopScan()
    log.info("BLECentral deinitializing")
  }
}
