//
//  TaggrApp.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import SwiftUI

@main
struct TaggrApp: App {
  
  /* delegate for reinstantiating BLECentral and BLEPeripheral */
  @UIApplicationDelegateAdaptor private var taggrAppDelegate: TaggrAppDelegate
  
  let defaults = UserDefaults.standard
  
  /* persistence used for leaderboard stats and pins */
  let persistenceController = PersistenceController.shared
  
  /* we need to reinstantiate central and peripheral and insert it into a manager */
  
  /* here we define one bluetooth manager to be created and sent into the environment */
  @StateObject var bluetoothManager = BLEManager(central: BLECentral(uuid: UUID().uuidString), peripheral: BLEPeripheral(uuid: UUID().uuidString))
  
  init() {
    /* used to initialize anything the app needs */
    if !defaults.bool(forKey: "isTagged") {
      // sets the tag status to false at the launch of the app
      defaults.set(false, forKey: "isTagged")
    }
    
  }
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .environmentObject(bluetoothManager)        /* this puts a single instance of bluetoothManager in the environment for all views to access */
    }
  }
}
