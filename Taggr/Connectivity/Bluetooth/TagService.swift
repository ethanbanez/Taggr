//
//  TagService.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/6/23.
//

import Foundation
import CoreBluetooth

/* Tag Service should be unique for each group made but the same for all devices in the group
    so that the central know what to write to */
let serviceUUID = CBUUID(string: "com.taggr.bluetooth.service.group-id-here")
let characteristicUUID = CBUUID(string: "com.taggr.characteristic.group-id-here")

struct TagService {
  var service: CBMutableService
  var characteristic: CBMutableCharacteristic
  init() {
    service = CBMutableService(type: serviceUUID, primary: true)
    characteristic = CBMutableCharacteristic(type: characteristicUUID,
                                             properties: CBCharacteristicProperties(arrayLiteral: [.writeWithoutResponse]),
                                             value: Data([0x0]),
                                             permissions: [.writeable])
    
    /* how many characteristics do I need for the service? I think just the tag status… or maybe the location data? */
    service.characteristics = [characteristic]
  }
}
