//
//  WritableProtocol
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

internal enum WritableTLState: Int {
    case Reading
    case Writing
    case Connected
    case Created
    case Errored
    case Unknown
}

internal protocol ConnectableTL {
    var connectableDelegate: ConnectableTLDelegate? { get set }

    func connect(to address: String) throws
}

internal protocol ConnectableTLDelegate {
    func connection(didChangeState state: WritableTLState)

    func create(didCreate data: Any?, _ error: Error?)
    func connect(didConnect data: Any?, _ error: Error?)
}

internal protocol WritableTL: ConnectableTL {
    var writableDelegate: WritableTLDelegate? { get set }

    func write(data: [UInt8]) throws

    func startReading() throws
    func stopReading() throws
}

internal protocol WritableTLDelegate {
    func writable(didReceive data: [UInt8]?, _ error: Error?)

    func writable(didWrite remainingData: [UInt8], _ error: Error?)

    func writable(didStopReading: Bool, _ error: Error?)
}

internal protocol ProtocolManagerDelegate {
    func state(didChange state: WritableTLState)
}
