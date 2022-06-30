//
//  WritableProtocol
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

@objc public enum WritableTLState: Int {
    case Reading
    case Writing
    case Connected
    case Created
    case Errored
    case Unknown
}

public protocol ConnectableTL {
    var connectableDelegate: ConnectableTLDelegate? { get set }

    func connect(to address: String) throws
}

public protocol ConnectableTLDelegate {
    func connection(didChangeState state: WritableTLState)

    func create(didCreate data: Any?, _ error: Error?)
    func connect(didConnect data: Any?, _ error: Error?)
}

public protocol WritableTL: ConnectableTL {
    var writableDelegate: WritableTLDelegate? { get set }

    func write(data: [UInt8]) throws

    func startReading() throws
    func stopReading() throws
}

public protocol WritableTLDelegate {
    func writable(didReceive data: [UInt8]?, _ error: Error?)

    func writable(didWrite remainingData: [UInt8], _ error: Error?)

    func writable(didStopReading: Bool, _ error: Error?)
}
