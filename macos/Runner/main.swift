import Cocoa

// Ignore SIGPIPE to prevent the app from being killed when writing to a
// broken pipe (e.g. Xcode debugger console disconnects). This is a common
// issue with Flutter macOS apps launched from Xcode.
signal(SIGPIPE, SIG_IGN)

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
