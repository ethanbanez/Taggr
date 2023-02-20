//
//  StatusView.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/16/23.
//

import Foundation
import SwiftUI

struct StatusView: View {
  
  /* we expect to find a bluetooth manager in the environment */
  @EnvironmentObject var bluetoothManager: BLEManager
  
  /* we access the bluetooth managers published property */
  var body: some View {
    VStack {
      Text(bluetoothManager.tagged.description)
    }
  }
}

struct StatusView_Preview: PreviewProvider {
  static var previews: some View {
    StatusView()
  }
}
