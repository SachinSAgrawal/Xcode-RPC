//
//  Utils.swift
//  SwordRPC
//
//  Created by Alejandro Alonso
//  Copyright © 2017 Alejandro Alonso. All rights reserved.
//

import Foundation

extension SwordRPC {
  
  func encode(_ value: Any) -> Data {
    do {
      return try JSONSerialization.data(withJSONObject: value, options: [])
    }catch {
      return Data()
    }
  }
  
  // Cast outside the throw since valid json that is not an object would trap otherwise
  func decode(_ json: Data) -> [String: Any] {
    let object = try? JSONSerialization.jsonObject(with: json, options: [])
    return object as? [String: Any] ?? [:]
  }
  
}
