//
//  Structs
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

public struct SessionData {
    public let accessToken: String
    public let publicKey: String
    public let commands: Commands

    public init(accessToken: String, publicKey: String, commands: Commands) {
        self.accessToken = accessToken
        self.publicKey = publicKey
        self.commands = commands
    }
}

public enum CommandType: String, CaseIterable {
    case Start = "start"
    case Stop = "stop"
    case Noop = "noop"
    case EndSession = "end_session"
}

public typealias Commands = [CommandType: String]
