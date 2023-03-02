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
private let localReadyCharacteristicUUID = CBUUID(string: "C09EC5CD-2573-4C0C-82B2-B3259E195D53")
private let localReadyToTagCharacteristicUUID = CBUUID(string: "7951F562-37B9-4BB0-977E-2F130139FC66")




/* this service is used for disseminating the TagService to look for */
class GroupService {
  
  // service UUID used to discover the other peripherals that have this service
  let serviceUUID = groupServiceUUID
  let service: CBMutableService = CBMutableService(type: groupServiceUUID, primary: true)
  
  // service characteristic UUID used to write to the other peripherals the real TagServiceUUID of the sending device
  let tagServiceUUID = localCurrentTagServiceUUID
  
  // characteristic characteristic UUID used to write to the other peripherals the real TagCharacteristicUUID of the sending device
  let tagCharacteristicUUID = localCurrentTagCharacteristicUUID
  
  let readyCharacteristicUUID = localReadyCharacteristicUUID
  
  let readyToTagCharacteristicUUID = localReadyToTagCharacteristicUUID
  
  let tagServiceCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localCurrentTagServiceUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
  
  let tagCharacteristicCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localCurrentTagCharacteristicUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
  
  let readyCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localReadyCharacteristicUUID, properties: [.read, .indicate, .write], value: nil, permissions: [.readable, .writeable])
  
  let readyToTagCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: localReadyToTagCharacteristicUUID, properties: [.write, .indicate], value: nil, permissions: [.writeable])
  
}

