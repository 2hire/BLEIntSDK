//
//  ContentView.swift
//  BLEIntSDK_Example
//
//  Created by 2hire on 16/05/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import _2hire_BLEIntSDK
import SwiftUI
import os.log

struct ContentView: View {
    @State private var accessDataTokenString = ""
    @State private var client: Client?
    @State private var selectedCommand: CommandType = .Start
    @State private var buttonLoading: ButtonLoading? = nil
    @State private var isShowingAlert: Bool = false
    @State private var alertMessage: String?
    @State private var bodyMessage: String = ""

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            TextField(
                "Access data token",
                text: $accessDataTokenString
            )
            .frame(width: 250)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true).textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: {
                Task.init {
                    self.buttonLoading = .Create

                    do {
                        let key = "Az8OqWnCYYyKCmuAJYrKUXDryu1HjpowPoRB8JkD5RRe"

                        let commands: _2hire_BLEIntSDK.Commands = [
                            .Start:
                                "ADqK3S1Ls8tu2NRha3/BKhdQOu3qCZgRXY1q/tDIKjzQhhcC3XqPlAXvN+Ct58ih8R2jKqkEZyldkKM0yvphMWgL4aLjE7rLnL+sKpTTofT+iriD+Ab3uhqrdVkSlHsfLGMfqAYvPvOHVhz8LoLoHK58EPsh/4PejhKBTpXPhbFpbO5dBllwdQJco9dSg4E38EDexbOmn5rcndwNWGLrGAY=",
                            .Stop: "AeUnVRMt7CF6dF6Ee3j3xDr+/MFVnZKN1L94oPVSiWHiSdV5/0TodK4zV3CkE9h67jQ8P4yym9vXqD6WoFt9flyxGWswV95d0RYX96w8W6UnCu3FLdWwgQYwAVCwmTU1Gqj3rXjzJs1fNgic0thn1cFqLtgNQefGm42zzivS48PBD2Mdk3LyFzzqJVw+HMCPG4x+sbkor8UcKhuI+0043Ig=",
                            .Noop:
                                "AlbBTYOrZb2IO1kJd8uEnRgDsQE38yj6mRAiuQmrgW4wUOu0FPHKxZ3oN95tzf3zpKE1x2YcSqOavIdd3FvDwtm+GF9ISZ+/wHdwbfO4N0ODFJ7zgU9XVj+tflfyMYiLkbRQoeZMs4TR5eyIQ51o8FQoXKtdsesn8COZd6dtNPkcUL2+T6UdKyUHb9hLIs4U8ne7C3GmScsZiAzWlRKS3x4=",
                            .Locate: "",
                            .EndSession:
                                "/wz88sby9ft9Na1dp/Iq9Wwp+EQt04Xjh7rceWCVxs4Px8kXPyvjhsZuFHZ/usOhlV80Yh3X67VC2XyQl0pSbp29XCRmyAsFSblX8m60ABZXMFaQAysAHriDUh2sG4kesMAdrPxRDhRmeFA9yO5LHb4GYNalw/NC94EQm4BZAn//mgm/UEBTkfuJ2qj7qBY54La23Romht5O/Qa1bu3X5ds=",
                        ]

                        let client = Client.init()
                        self.client = client
                        try client.sessionSetup(
                            with: SessionData(accessToken: accessDataTokenString, publicKey: key, commands: commands)
                        )
                    }
                    catch {
                        processResponse(alertMessage: "Error!")
                        os_log(
                            "Something went wrong while connecting: %@",
                            log: .user,
                            type: .error,
                            error.localizedDescription
                        )
                    }

                    self.buttonLoading = nil
                }
            }) {
                if self.buttonLoading == .Create {
                    ProgressView(value: 1).progressViewStyle(CircularProgressViewStyle()).padding()
                }
                else {
                    Text("Create")
                        .padding(.vertical, 8.0)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 250.0)
            .background(.orange)
            .cornerRadius(8.0)

            Spacer()

            Button(action: {
                Task.init {
                    self.buttonLoading = .Start

                    do {
                        let response = try await client!.connectToVehicle(withIdentifier: "C6F59B130C7C")

                        processResponse(
                            alertMessage: "Command OK!",
                            bodyMessage: Data(response.additionalPayload).base64EncodedString()
                        )
                    }
                    catch {
                        processResponse(alertMessage: "Error!")
                        os_log("error %@", log: .user, type: .error, error.localizedDescription)
                    }

                    self.buttonLoading = nil
                }

            }) {
                if self.buttonLoading == .Start {
                    ProgressView(value: 1).progressViewStyle(CircularProgressViewStyle()).padding()
                }
                else {
                    Text("Start sequence")
                        .padding()
                        .foregroundColor(.white)
                }
            }
            .disabled($buttonLoading.wrappedValue != nil || $client.wrappedValue == nil)
            .frame(width: 250.0)
            .background(.green)
            .cornerRadius(8.0)

            Button(action: {
                Task.init {
                    self.buttonLoading = .End

                    do {
                        let response = try await client!.endSession()

                        processResponse(
                            alertMessage: "Command OK!",
                            bodyMessage: Data(response.additionalPayload).base64EncodedString()
                        )
                    }
                    catch {
                        processResponse(alertMessage: "Error!")
                        os_log("error %@", log: .user, type: .error, error.localizedDescription)
                    }

                    self.buttonLoading = nil
                }
            }) {
                if self.buttonLoading == .End {
                    ProgressView(value: 1).progressViewStyle(CircularProgressViewStyle()).padding()
                }
                else {
                    Text("End Session")
                        .padding()
                        .foregroundColor(.white)
                }
            }
            .disabled($buttonLoading.wrappedValue != nil || $client.wrappedValue == nil)
            .frame(width: 250.0)
            .background(.red)
            .cornerRadius(8.0)

            Picker(selection: $selectedCommand, label: Text("Picker")) {
                Text("Start").tag(CommandType.Start)
                Text("Stop").tag(CommandType.Stop)
                Text("Noop").tag(CommandType.Noop)
                Text("Locate").tag(CommandType.Locate)
            }.pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)

            Button(action: {
                Task.init {
                    self.buttonLoading = .SendCommand

                    do {
                        let response = try await client!.sendCommand(type: $selectedCommand.wrappedValue)
                        processResponse(
                            alertMessage: "Command OK!",
                            bodyMessage: Data(response.additionalPayload).base64EncodedString()
                        )

                    }
                    catch {
                        processResponse(alertMessage: "Error!")
                        os_log("error %@", log: .user, type: .error, error.localizedDescription)
                    }

                    self.buttonLoading = nil
                }
            }) {
                if self.buttonLoading == .SendCommand {
                    ProgressView(value: 1).progressViewStyle(CircularProgressViewStyle()).padding()
                }
                else {
                    Text("Send command")
                        .padding()
                        .foregroundColor(.white)
                }
            }
            .disabled($buttonLoading.wrappedValue != nil || $client.wrappedValue == nil)
            .frame(width: 250.0)
            .background(.blue)
            .cornerRadius(8.0)

            VStack(alignment: .leading) {
                Text("Last Command response:")
                    .padding(.bottom, 5)

                Text($bodyMessage.wrappedValue)
                    .multilineTextAlignment(.leading)
            }.padding(.top, 48)

            Spacer()

        }
        .padding()
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("Output"),
                message: Text($alertMessage.wrappedValue!),
                dismissButton: .default(
                    Text("OK"),
                    action: {
                        self.isShowingAlert = false
                        self.alertMessage = nil
                    }
                )
            )
        }
    }

    func processResponse(alertMessage: String, bodyMessage: String? = nil) {
        self.alertMessage = alertMessage.description
        self.isShowingAlert = true

        if let body = bodyMessage {
            self.bodyMessage = body
        }
        else {
            self.bodyMessage = ""
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "BundleIdentifier not set"

    fileprivate static let user = OSLog(subsystem: subsystem, category: "👨🏽‍💻 User")
}

private enum ButtonLoading {
    case Create
    case Start
    case End
    case SendCommand
}
