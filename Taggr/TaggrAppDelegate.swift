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
  
  
  
  func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    log.info("AppDelegate willFinishLaunchingWithOptions getting ready to launch app")
    
    
    /*
     Here I should reinstantiate all the services that the bluetooth services need
     How does state preservation and restoration work with services?
      Peripherals can restore the services that they used to have published which…
        should always be the same for everyone in a group which should be enough
        to restore the services that needed to look for?
      Centrals can restore any services that they were scanning for before termination
        which does not include any services that were not being actively scanned for…
        But technically the central will be scanning as well as trying to connect…
        So we could reinstantiate the service that it was scanning for… which should
        be the same for the whole tagging lifecycle and only changes during group creation
     */
    
    
    
    
    // if there were no options then the first time this app started ever?
    // this assumption could be wrong
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
      
      
      log.info("willFinishLaunchingWithOptions no launch options. Creating central and peripheral managers with new uuids")
      return true
      
    }
    
    
    /* Entering from the background… */
    let centralArray = options[UIApplication.LaunchOptionsKey.bluetoothCentrals] as! [UUID]
    let peripheralArray = options[UIApplication.LaunchOptionsKey.bluetoothPeripherals] as! [UUID]
    let centralUUID = centralArray[0]
    let peripheralUUID = peripheralArray[0]
    
    
    /*
     if the device is not in a group then assign the delegate to the BLEGroup class, otherwise it's in the process of tagging
     */
    if !UserDefaults.standard.bool(forKey: "inGroup") {
      centralManager = CBCentralManager(delegate: BLEGroup.shared, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: centralUUID.uuidString])
      peripheralManager = CBPeripheralManager(delegate: BLEGroup.shared, queue: .main, options: [CBPeripheralManagerOptionRestoreIdentifierKey: peripheralUUID.uuidString])
      
      BLEGroup.shared.central = centralManager
      return true
      
    } else {
      
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
  }
  
  
  
  /* we cannot create BLECentral or peripheral equivalent but we can create a CBCentralManager, and peripheral equivalent, object that we use to create a BLECentral, and peripheral equivalent. Then we BLEPeripheral and BLECentral to create the BLEManager */
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    log.info("didFinishLaunchingWithOptions completed")
    return true
  }
  
  
  func applicationWillTerminate(_ application: UIApplication) {
    /*
     Save any relevant information to user defaults
     */
  }
}
