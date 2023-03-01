//
//  TagService.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/6/23.
//

import Foundation
import CoreBluetooth
import os

/*
 Tag Service should be unique for each group made but the same for all devices in the group
    so that the central know what to write to */
/*
 There should be a personal tagService… and then a group Tag service for being written to when you join a group and someone else started it
 personal services are only read from while public services which are when you're finding are written to.
 
 The service needs to be mutable to change for different groups and such
 */

struct TagService {
  var servicesWrittenTo = 0
  
  var configured: Bool = false
  
  var serviceUUID: CBUUID {
    didSet {
      UserDefaults.standard.set(serviceUUID.uuidString, forKey: "TagServiceUUID")
      service = CBMutableService(type: serviceUUID, primary: true)
      servicesWrittenTo += 1
      if servicesWrittenTo >= 2 {
        configured = true
      }
    }
  }
  
  var characteristicUUID: CBUUID {
    didSet {
      UserDefaults.standard.set(characteristicUUID.uuidString, forKey: "TagCharacteristicUUID")
      characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
      servicesWrittenTo += 1
      if servicesWrittenTo >= 2 {
        configured = true
      }
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

extension TagService {
  func tagServiceReady() -> Bool {
    if servicesWrittenTo >= 2 {
      return true
    }
    return false
  }
}


