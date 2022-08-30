//
//  Extensions
//
//  Copyright © 2022 2hire.io. All rights reserved.
//

import Foundation

extension Data {
    var hexEncodedString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(count * 2)

        for byte in self {
            let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }

        return String(utf16CodeUnits: hexChars, count: hexChars.count)
    }
}

extension Date {
    var timestamp: [UInt8] {
        var time = Int64(self.timeIntervalSince1970)
        let data = Data(bytes: &time, count: MemoryLayout<Int64>.size)

        return [UInt8](data)
    }
}

extension Array where Element == UInt8 {
    static func from(value: UInt32) -> [UInt8] {
        var array: [UInt8] = []

        Swift.withUnsafeBytes(of: value.littleEndian) {
            array.append(contentsOf: $0)
        }

        return array
    }
}

extension WritableTLState {
    var description: String {
        switch self {
        case .Reading:
            return "Reading"
        case .Writing:
            return "Writing"
        case .Connected:
            return "Connected"
        case .Created:
            return "Created"
        case .Errored:
            return "Errored"
        case .Unknown:
            return "Unknown"
        }
    }
}
