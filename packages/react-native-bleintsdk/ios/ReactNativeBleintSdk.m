#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE (ReactNativeBleintSdk, NSObject)

RCT_EXTERN_METHOD(sessionSetup
                  : (NSString)accessToken commands
                  : (NSDictionary)commands publicKey
                  : (NSString)publicKey withResolver
                  : (RCTPromiseResolveBlock)resolve withRejecter
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(connect
                  : (NSString)address withResolver
                  : (RCTPromiseResolveBlock)resolve withRejecter
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(sendCommand
                  : (NSString)commandType withResolver
                  : (RCTPromiseResolveBlock)resolve withRejecter
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(endSession
                  : (RCTPromiseResolveBlock)resolve withRejecter
                  : (RCTPromiseRejectBlock)reject)
@end
