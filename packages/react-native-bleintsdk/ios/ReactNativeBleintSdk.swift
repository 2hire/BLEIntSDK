import _2hire_BLEIntSDK

@objc(ReactNativeBleintSdk)
class ReactNativeBleintSdk: NSObject {

    private static let client: Client = Client.init()

    @objc(sessionSetup:commands:publicKey:withResolver:withRejecter:)
    func sessionSetup(
        _ accessToken: String,
        commands: NSDictionary,
        publicKey: String,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        do {
            try Self.client.sessionSetup(
                with: SessionData(
                    accessToken: accessToken,
                    publicKey: publicKey,
                    commands: _2hire_BLEIntSDK.Commands.fromDictionary(dictionary: commands)
                )
            )

            resolve(true)
        }
        catch {
            reject("error", "Something went wrong while creating (\(error.localizedDescription))", error)
        }
    }

    @objc(connect:withResolver:withRejecter:)
    func connect(
        _ address: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task.init {
            do {
                let response = try await Self.client.connectToVehicle(withIdentifier: address)

                resolve(response.asDictionary)
            }
            catch {
                reject("error", "Something went wrong while connecting to vehicle (\(error.localizedDescription))", error)
            }
        }
    }

    @objc(sendCommand:withResolver:withRejecter:)
    func sendCommand(
        _ commandType: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task.init {
            do {
                guard let command = CommandType(rawValue: commandType) else {
                    reject("command_not_found", "Command not found", BridgeError.InvalidArgument)
                    return
                }

                let response = try await Self.client.sendCommand(type: command)
                resolve(response.asDictionary)
            }
            catch {
                reject("error", "Something went wrong while sending command to vehicle (\(error.localizedDescription))", error)
            }
        }
    }

    @objc(endSession:withRejecter:)
    func endSession(
        _ resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        Task.init {
            do {
                let response = try await Self.client.endSession()
                resolve(response.asDictionary)
            }
            catch {
                reject("error", "Something went wrong while ending session (\(error.localizedDescription))", error)
            }
        }
    }
}

extension _2hire_BLEIntSDK.CommandResponse: Encodable {
    private enum CodingKeys: String, CodingKey {
        case success = "success"
        case additionalPayload = "payload"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(Data(self.additionalPayload).base64EncodedString(), forKey: .additionalPayload)
        try container.encode(self.success, forKey: .success)
    }

    fileprivate var asDictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }

        return (try? JSONSerialization.jsonObject(with: data)).flatMap { $0 as? [String: Any] }
    }
}

extension _2hire_BLEIntSDK.Commands {
    fileprivate static func fromDictionary(dictionary: NSDictionary) -> Self {
        var result: Self = [:]

        _2hire_BLEIntSDK.CommandType.allCases.forEach {
            if let value = dictionary[$0.rawValue] as? String {
                result[$0] = value
            }
        }

        return result
    }
}

enum BridgeError: Error {
    case InvalidArgument
}
