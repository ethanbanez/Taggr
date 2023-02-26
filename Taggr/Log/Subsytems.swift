//
//  Logger.swift
//  Taggr
//
//  Created by Ethan Bañez on 2/3/23.
//

import Foundation

private let bundleID = Bundle.main.bundleIdentifier!

enum Subsystem: String, CaseIterable, CustomStringConvertible {
  case tag, networking, peristence, lifecycle, group
  
  var description: String {
    switch self {
    case .tag:
      return bundleID + ".tag"
    case .networking:
      return bundleID + ".networking"
    case .peristence:
      return bundleID + ".persistence"
    case .lifecycle:
      return bundleID + ".lifecycle"
    case .group:
      return bundleID + ".group"
    }
  }
}
