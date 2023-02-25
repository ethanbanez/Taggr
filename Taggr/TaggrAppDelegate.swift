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
  private var log = Logger(subsystem: Subsystem.lifecycle.description, category: "AppDelegate")
  
  /* No bluetooth manager inserted into the environment before this… */
//  @EnvironmentObject private var bluetoothManager: BLEManager
  
  var centralManager: CBCentralManager?
  var peripheralManager: CBPeripheralManager?
  
  func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
    log.info("AppDelegate shouldSaveSecureApplicationState set to true")
    return true
  }
  
  func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
    log.info("AppDelegate shouldRestoreSecureApplicationState set to true")
    return true
  }
  
  /* this happens before didFinishLaunching… maybe we can send objects into the environment? */
  func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    log.info("AppDelegate willFinishLaunchingWithOptions getting ready to launch app")
    // if there were no options then the first time this app started ever?
    guard let options = launchOptions else {
      
      /*
       No bluetooth manager inserted into the environment before this…!!!!
       Therefore:
          Set up the bluetooth manager with its delegates
       */
      let centralUUID: UUID = UUID()
      let peripheralUUID: UUID = UUID()
      
      centralManager = CBCentralManager(delegate: BLEManager.shared, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: centralUUID.uuidString])
      BLEManager.shared.central = centralManager
      BLEManager.shared.centralUUID = centralUUID
      
      peripheralManager = CBPeripheralManager(delegate: BLEManager.shared, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheralUUID.uuidString])
      BLEManager.shared.peripheral = peripheralManager
      BLEManager.shared.peripheralUUID = peripheralUUID
      
      /* means that this is the first time launching… then?? */
      
      log.info("willFinishLaunchingWithOptions no launch options. Creating central and peripheral managers with new uuids")
      return true
    }
    
    let centralArray = options[UIApplication.LaunchOptionsKey.bluetoothCentrals] as! [UUID]
    let peripheralArray = options[UIApplication.LaunchOptionsKey.bluetoothPeripherals] as! [UUID]
    let centralUUID = centralArray[0]
    let peripheralUUID = peripheralArray[0]
    
    centralManager = CBCentralManager(delegate: BLEManager.shared, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: centralUUID.uuidString])
    BLEManager.shared.central = centralManager
    BLEManager.shared.centralUUID = centralUUID
    
    peripheralManager = CBPeripheralManager(delegate: BLEManager.shared, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheralUUID.uuidString])
    BLEManager.shared.peripheral = peripheralManager
    BLEManager.shared.peripheralUUID = peripheralUUID
    
    log.info("willFinishLaunchingWithOptions restoring uuids for central: \(centralUUID.uuidString)")
    log.info("willFinishLaunchingWithOptions restoring uuids for peripheral: \(peripheralUUID.uuidString)")
    log.info("willFinishLaunchingWithOptions launch options available. Reinstantiated central and peripheral managers")
    return true
  }
  
  /* we cannot create BLECentral or peripheral equivalent but we can create a CBCentralManager, and peripheral equivalent, object that we use to create a BLECentral, and peripheral equivalent. Then we BLEPeripheral and BLECentral to create the BLEManager */
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    log.info("didFinishLaunchingWithOptions completed")
    return true
  }
}
