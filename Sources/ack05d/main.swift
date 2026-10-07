import Foundation

// ack05d — userspace driver for the XPPen ACK05 shortcut remote over Bluetooth LE.
//
//   ack05d                        run the driver using the config file
//   ack05d --identify             print every button/wheel event by name; no actions run
//   ack05d --check-accessibility  check accessibility & event tap access; poll live until granted
//   ack05d --debug                log every button event, wheel event, and battery heartbeat
//   ack05d --config P             use config file at path P
//
// See README.md for the protocol and config format.

let daemon = Daemon(options: Options(arguments: CommandLine.arguments,
                                     environment: ProcessInfo.processInfo.environment))
daemon.run()
