//
//  PeripheralView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/20/23.
//

import Foundation
import SwiftUI

/*
 Allows the user to select to connect to a specific peripheral
 */
struct PeripheralView: View {
  
  var bluetoothManager = BLEManager.shared
  
  var body: some View {
    ForEach(bluetoothManager.discoveredPeripherals!, id: \.self, content: {
      peripheral in Text(peripheral.description).onTapGesture {
        bluetoothManager.central?.connect(peripheral)
      }
    })
  }
}
