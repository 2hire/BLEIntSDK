import Foundation
import BLEIntSDK

class BLEIntSDKCordova: CDVPlugin {

    private static let sdkClient: BLEIntSDK.Client = Client()

    @objc(sessionSetup:)
    func sessionSetup(command: CDVInvokedUrlCommand) {
        do {
            guard let accessToken = command.argument(at: 0) as? String,
                  let commands = command.argument(at: 1) as? NSDictionary,
                  let publicKey = command.argument(at: 2) as? String
            else {
                throw BridgeError.InvalidArgument
            }

            try Self.sdkClient.sessionSetup(
                with: SessionData(
                    accessToken: accessToken,
                    publicKey: publicKey,
                    commands: BLEIntSDK.Commands.fromDictionary(dictionary: commands)
                )
            )

            self.commandDelegate.send(
                CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: true
                ),
                callbackId: command.callbackId
            )
        }
        catch let error as BLEIntSDKError {
            self.commandDelegate.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: [
                        "code": error.rawValue,
                        "message":
                            "Something went wrong while creating (\(error.errorDescription ?? error.localizedDescription))",
                    ]
                ),
                callbackId: command.callbackId
            )
        }
        catch {
            self.commandDelegate.send(
                CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: "Something went wrong while creating (\(error.localizedDescription))"
                ),
                callbackId: command.callbackId
            )
        }

    }

    @objc(connect:)
    func connect(command: CDVInvokedUrlCommand) {
        Task.init {
            do {
                guard let address = command.argument(at: 0) as? String else {
                    throw BridgeError.InvalidArgument
                }

                let response = try await Self.sdkClient.connectToVehicle(withIdentifier: address)

                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_OK,
                        messageAs: response.asDictionary
                    ),
                    callbackId: command.callbackId
                )
            }
            catch let error as BLEIntSDKError {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs: [
                            "code": error.rawValue,
                            "message":
                                "Something went wrong while connecting to vehicle (\(error.errorDescription ?? error.localizedDescription))",
                        ]
                    ),
                    callbackId: command.callbackId
                )
            }
            catch {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs: "Something went wrong while connecting to vehicle (\(error.localizedDescription))"
                    ),
                    callbackId: command.callbackId
                )
            }
        }
    }

    @objc(sendCommand:)
    func sendCommand(command: CDVInvokedUrlCommand) {
        Task.init {
            do {
                guard let _command = command.argument(at: 0) as? String,
                      let commandType = BLEIntSDK.CommandType(rawValue: _command)
                else {
                    throw BridgeError.InvalidArgument
                }

                let response = try await Self.sdkClient.sendCommand(type: commandType)

                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_OK,
                        messageAs: response.asDictionary
                    ),
                    callbackId: command.callbackId
                )
            }
            catch let error as BLEIntSDKError {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs: [
                            "code": error.rawValue,
                            "message":
                                "Something went wrong while sending command to vehicle (\(error.errorDescription ?? error.localizedDescription))",
                        ]
                    ),
                    callbackId: command.callbackId
                )
            }
            catch {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs:
                            "Something went wrong while sending command to vehicle (\(error.localizedDescription))"
                    ),
                    callbackId: command.callbackId
                )
            }
        }
    }

    @objc(endSession:)
    func endSession(command: CDVInvokedUrlCommand) {
        Task.init {
            do {
                let response = try await Self.sdkClient.endSession()

                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_OK,
                        messageAs: response.asDictionary
                    ),
                    callbackId: command.callbackId
                )
            }
            catch let error as BLEIntSDKError {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs: [
                            "code": error.rawValue,
                            "message":
                                "Something went wrong while ending session (\(error.errorDescription ?? error.localizedDescription))",
                        ]
                    ),
                    callbackId: command.callbackId
                )
            }
            catch {
                self.commandDelegate.send(
                    CDVPluginResult(
                        status: CDVCommandStatus_ERROR,
                        messageAs:
                            "Something went wrong while ending session (\(error.localizedDescription))"
                    ),
                    callbackId: command.callbackId
                )
            }
        }
    }
}

extension BLEIntSDK.CommandResponse: Encodable {
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

extension BLEIntSDK.Commands {
    fileprivate static func fromDictionary(dictionary: NSDictionary) -> Self {
        var result: Self = [:]

        BLEIntSDK.CommandType.allCases.forEach {
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
