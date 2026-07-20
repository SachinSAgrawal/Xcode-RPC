//
//  RPC.swift
//  SwordRPC
//
//  Created by Alejandro Alonso
//  Copyright © 2017 Alejandro Alonso. All rights reserved.
//

import Foundation
import Socket

extension SwordRPC {

  func createSocket() {
    // Drop any previous socket so a failed connect attempt cannot leak or be reused
    self.socket?.close()
    self.socket = nil
    self.readBuffer = Data()

    do {
      self.socket = try Socket.create(family: .unix, proto: .unix)
      try self.socket?.setBlocking(mode: false)
    }catch {
      guard let error = error as? Socket.Error else {
        print("[SwordRPC] Unable to create rpc socket")
        return
      }

      print("[SwordRPC] Error creating rpc socket: \(error)")
    }
  }

  func send(_ msg: String, _ op: OP) throws {
    let payload = msg.data(using: .utf8)!

    // Build the header ahead of the payload so nothing has to be shifted in place
    var frame = Data(capacity: 8 + payload.count)
    withUnsafeBytes(of: op.rawValue.littleEndian) { frame.append(contentsOf: $0) }
    withUnsafeBytes(of: UInt32(payload.count).littleEndian) { frame.append(contentsOf: $0) }
    frame.append(payload)

    try frame.withUnsafeBytes { buffer in
      _ = try self.socket?.write(from: buffer.baseAddress!, bufSize: buffer.count)
    }
  }

  // Pull whatever is available into the rolling buffer so partial frames are never dropped
  func fillBuffer() throws {
    var chunk = Data()

    let read = try self.socket?.read(into: &chunk) ?? 0

    if read > 0 {
      self.readBuffer.append(chunk)
    }
  }

  func receive() {
    self.worker.asyncAfter(
      deadline: .now() + .milliseconds(self.handlerInterval)
    ) {
      guard let isConnected = self.socket?.isConnected, isConnected else {
        self.disconnectHandler?(self, nil, nil)
        self.delegate?.swordRPCDidDisconnect(self, code: nil, message: nil)
        return
      }

      self.receive()

      do {
        try self.fillBuffer()

        // Drain every whole frame and leave any partial one in the buffer for next time
        while self.readBuffer.count >= 8 {
          let header = [UInt8](self.readBuffer.prefix(8))

          let opValue = UInt32(header[0]) | UInt32(header[1]) << 8
            | UInt32(header[2]) << 16 | UInt32(header[3]) << 24
          let length = UInt32(header[4]) | UInt32(header[5]) << 8
            | UInt32(header[6]) << 16 | UInt32(header[7]) << 24

          // A bad header means the stream is desynced and cannot be realigned by guessing
          guard length < 1_000_000, let op = OP(rawValue: opValue) else {
            print("[SwordRPC] Dropping desynced connection")
            self.socket?.close()
            return
          }

          let total = 8 + Int(length)

          // Wait for the rest of the payload rather than consuming a half frame
          guard self.readBuffer.count >= total else { return }

          let payload = Data(self.readBuffer.dropFirst(8).prefix(Int(length)))
          self.readBuffer = Data(self.readBuffer.dropFirst(total))

          self.handlePayload(op, payload)
        }

      }catch {
        return
      }
    }
  }

  func handshake() {
    do {
      let json = """
      {
        "v": 1,
        "client_id": "\(self.appId)"
      }
      """

      try self.send(json, .handshake)
    }catch {
      print("[SwordRPC] Unable to handshake with Discord")
      self.socket?.close()
    }
  }

  func subscribe(_ event: String) {
    let json = """
    {
      "cmd": "SUBSCRIBE",
      "evt": "\(event)",
      "nonce": "\(UUID().uuidString)"
    }
    """

    try? self.send(json, .frame)
  }

  func handlePayload(_ op: OP, _ json: Data) {
    switch op {
    case .close:
      // Discord does not always populate these so treat them as optional
      let data = self.decode(json)
      let code = data["code"] as? Int
      let message = data["message"] as? String
      self.socket?.close()
      self.disconnectHandler?(self, code, message)
      self.delegate?.swordRPCDidDisconnect(self, code: code, message: message)

    case .ping:
      guard let payload = String(data: json, encoding: .utf8) else { return }
      try? self.send(payload, .pong)

    case .frame:
      self.handleEvent(self.decode(json))

    default:
      return
    }
  }

  func handleEvent(_ data: [String: Any]) {
    guard let evt = data["evt"] as? String,
          let event = Event(rawValue: evt) else {
      return
    }

    // Anything off the socket is untrusted so a malformed frame is ignored rather than fatal
    guard let data = data["data"] as? [String: Any] else {
      return
    }

    switch event {
    case.error:
      guard let code = data["code"] as? Int,
            let message = data["message"] as? String else { return }
      self.errorHandler?(self, code, message)
      self.delegate?.swordRPCDidReceiveError(self, code: code, message: message)

    case .join:
      guard let secret = data["secret"] as? String else { return }
      self.joinGameHandler?(self, secret)
      self.delegate?.swordRPCDidJoinGame(self, secret: secret)

    case .joinRequest:
      guard let requestData = data["user"] as? [String: Any],
            let joinRequest = try? self.decoder.decode(
              JoinRequest.self, from: self.encode(requestData)
            ),
            let secret = data["secret"] as? String else { return }
      self.joinRequestHandler?(self, joinRequest, secret)
      self.delegate?.swordRPCDidReceiveJoinRequest(self, request: joinRequest, secret: secret)

    case .ready:
      self.connectHandler?(self)
      self.delegate?.swordRPCDidConnect(self)
      self.updatePresence()

    case.spectate:
      guard let secret = data["secret"] as? String else { return }
      self.spectateGameHandler?(self, secret)
      self.delegate?.swordRPCDidSpectateGame(self, secret: secret)
    }
  }

  // Instead of queuing this block to run every 15 seconds
  // let setPresence() call this function so that presence can be updated on demand.

  // The Discord API has presence update limit of once per 15 seconds
  // the API will enforce this limit, so we don't have to do it

  func updatePresence() {
//    self.worker.asyncAfter(deadline: .now() + .seconds(15)) { [unowned self] in
//      self.updatePresence()
//
//      guard let presence = self.presence else {
//        return
//      }
//
//      self.presence = nil

      // Send null to clear the activity since there may be no presence set yet
      var activity = "null"

      if let presence = self.presence,
         let encoded = try? self.encoder.encode(presence),
         let string = String(data: encoded, encoding: .utf8) {
        activity = string
      }

      let json = """
          {
            "cmd": "SET_ACTIVITY",
            "args": {
              "pid": \(self.pid),
              "activity": \(activity)
            },
            "nonce": "\(UUID().uuidString)"
          }
          """

      try? self.send(json, .frame)
//    }
  }

}
