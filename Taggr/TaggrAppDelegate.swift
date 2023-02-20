//
//  TaggrAppDelegate.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/16/23.
//

import Foundation
import UIKit
import SwiftUI
import CoreBluetooth
import os

class TaggrAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
  var log = Logger(subsystem: Subsystem.lifecycle.description, category: "TaggrAppDelegate")
  @EnvironmentObject private var bluetoothManager: BLEManager
  var centralManager: CBCentralManager?
  var peripheralManager: CBPeripheralManager?
  
  func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
    return true
  }
  
  func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
    return true
  }
  
  /* this happens before didFinishLaunching… maybe we can send objects into the environment? */
  func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    
    // if there were no options then the first time this app started ever?
    guard let options = launchOptions else {
      bluetoothManager.central = BLECentral(uuid: UUID().uuidString)
      bluetoothManager.central.manager.delegate = bluetoothManager
      
      bluetoothManager.peripheral = BLEPeripheral(uuid: UUID().uuidString)
      bluetoothManager.peripheral.manager.delegate = bluetoothManager
      
      log.info("willFinishLaunchingWithOptions no launch options. Created central and peripheral managers")
      return true
    }
    
    var centralArray = options[UIApplication.LaunchOptionsKey.bluetoothCentrals] as! [UUID]
    var peripheralArray = options[UIApplication.LaunchOptionsKey.bluetoothPeripherals] as! [UUID]
    var centraluuid = centralArray[0]
    var peripheraluuid = peripheralArray[0]
    
    bluetoothManager.central = BLECentral(uuid: centraluuid.uuidString)
    bluetoothManager.central.manager.delegate = bluetoothManager
      
    bluetoothManager.peripheral = BLEPeripheral(uuid: peripheraluuid.uuidString)
    bluetoothManager.peripheral.manager.delegate = bluetoothManager
    
    log.info("willFinishLaunchingWithOptions launch options available. Reinstantiated central and peripheral managers")
    return true
  }
  
  
  /* we cannot create BLECentral or peripheral equivalent but we can create a CBCentralManager, and peripheral equivalent, object that we use to create a BLECentral, and peripheral equivalent. Then we BLEPeripheral and BLECentral to create the BLEManager */
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    log.info("didFinishLaunchingWithOptions completed")
    return true
  }
}
