//
//  StatusView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/16/23.
//

import Foundation
import SwiftUI

struct StatusView: View {
  
  /* we expect to find a bluetooth manager in the environment passed from main App */
  @EnvironmentObject var bluetoothManager: BLEManager
  
  /* we access the bluetooth managers published property */
  var body: some View {
    HStack (alignment: .top) {
      Text("Tag Status:").bold()
      Text(bluetoothManager.tagged.description)
    }.padding(.bottom)
    HStack (alignment: .center, spacing: 12) {
      if (bluetoothManager.discoveredPeripherals != nil) {
        PeripheralView()
      } else {
        Text("No peripherals discovered")
      }
    }
  }
}

struct StatusView_Preview: PreviewProvider {
  static var previews: some View {
    StatusView()
  }
}
