//
//  GroupService.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/25/23.
//

import Foundation
import CoreBluetooth

// this uuid never changes for any device
private let groupServiceUUID = CBUUID(string: "4E38F580-9DAF-460D-9A40-B28F696C48A2")

// these two uuids should change on group creation
private let localCurrentTagServiceUUID = CBUUID(string: "FE8908C0-D338-42AF-9C24-4E4FB1CAE395")
private let localCurrentTagCharacteristicUUID = CBUUID(string: "A67039CF-9332-40AD-9B6B-E7851D094356")


let shared = GroupService()


/* this service is used for disseminating the TagService to look for */
class GroupService {
  
  // service UUID used to discover the other peripherals that have this service
  static var serviceUUID = groupServiceUUID
  static var service: CBMutableService = CBMutableService(type: groupServiceUUID, primary: true)
  
  // service characteristic UUID used to write to the other peripherals the real TagServiceUUID of the sending device
  static var tagServiceUUID = localCurrentTagServiceUUID
  
  // characteristic characteristic UUID used to write to the other peripherals the real TagCharacteristicUUID of the sending device
  static var tagCharacteristicUUID = localCurrentTagCharacteristicUUID
  
  static var tagServiceCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localCurrentTagServiceUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
  
  static var tagCharacteristicCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localCurrentTagCharacteristicUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
  
}

