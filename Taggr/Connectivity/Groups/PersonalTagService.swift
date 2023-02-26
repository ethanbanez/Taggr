//
//  PersonalTagService.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/25/23.
//

import Foundation
import CoreBluetooth
import os


struct PersonalTagService {
  var serviceUUID: CBUUID {
    didSet {
      UserDefaults.standard.set(serviceUUID.uuidString, forKey: "TagServiceUUID")
      service = CBMutableService(type: serviceUUID, primary: true)
    }
  }
  
  var characteristicUUID: CBUUID {
    didSet {
      UserDefaults.standard.set(serviceUUID.uuidString, forKey: "TagCharacteristicUUID")
      characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
    }
  }
  
  var service: CBMutableService
  var characteristic: CBMutableCharacteristic
  
  // Can make the trade-off of whether we initialize the values here or make them an optional that is then initialized when the uuids are set… whichever is more efficient I guess…
  public init(serviceuuid: CBUUID, characteristicuuid: CBUUID) {
    serviceUUID = serviceuuid
    characteristicUUID = characteristicuuid
    
    service = CBMutableService(type: serviceuuid, primary: true)
    characteristic = CBMutableCharacteristic(type: characteristicuuid, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
  }
}

