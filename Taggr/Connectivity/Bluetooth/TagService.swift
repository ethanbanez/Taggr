//
//  TagService.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/6/23.
//

import Foundation
import CoreBluetooth
import os

/* Tag Service should be unique for each group made but the same for all devices in the group
    so that the central know what to write to */
let globalServiceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
let globalCharacteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")

struct TagService {
  var serviceUUID = globalServiceUUID
  var characteristicUUID = globalCharacteristicUUID
  var service: CBMutableService = CBMutableService(type: globalServiceUUID, primary: true)
  var characteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: globalCharacteristicUUID,
                                                    properties: [.writeWithoutResponse], value: nil, permissions: [.writeable])
}
