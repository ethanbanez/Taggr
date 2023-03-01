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

private let defaults = UserDefaults.standard

class TaggrAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
  
  private var log = Logger(subsystem: Subsystem.lifecycle.description, category: "AppDelegate")
  
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
      
      // may need to store this in UserDefaults as well so that it's the same every time for this device… since I don't think state restoration restores from a fully destroyed app
      let centralUUID: String = defaults.string(forKey: "CBCentralManagerUUID") ?? {
        log.info("storing the centralUUID UserDefaults")
        let uuid = UUID().uuidString
        defaults.set(uuid, forKey: "CBCentralManagerUUID")
        return uuid
      }()
      
      let peripheralUUID: String = defaults.string(forKey: "CBPeripheralManagerUUID") ?? {
        log.info("storing the peripheralUUID UserDefaults")
        let uuid = UUID().uuidString
        defaults.set(uuid, forKey: "CBPeripheralManagerUUID")
        return uuid
      }()
      
      log.info("init with central: \(centralUUID)")
      log.info("init with peripheral: \(peripheralUUID)")
      centralManager = CBCentralManager(delegate: BLEGroup.shared, queue: .main)    // do state preservation later…
      BLEGroup.shared.central = centralManager
//      BLEGroup.shared.centralUUID = UUID(uuidString: centralUUID)
      
      peripheralManager = CBPeripheralManager(delegate: BLEGroup.shared, queue: .main)
      BLEGroup.shared.peripheral = peripheralManager
//      BLEGroup.shared.peripheralUUID = UUID(uuidString: peripheralUUID)
      
      
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
    // stop advertising and such
    log.info("app is being terminated")
    
    if defaults.bool(forKey: "inGroup") {
      BLEManager.shared.peripheral?.removeAllServices()
      BLEManager.shared.peripheral?.stopAdvertising()
      BLEManager.shared.central?.stopScan()
    } else {
      BLEGroup.shared.peripheral?.removeAllServices()
      BLEGroup.shared.peripheral?.stopAdvertising()
      BLEGroup.shared.central?.stopScan()
    }
  }
}
