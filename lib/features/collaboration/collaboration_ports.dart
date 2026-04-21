import 'package:flutter/foundation.dart';

/// Port assignments for the built-in collaboration server.
///
/// Debug and release builds use different ports so both can run on the same
/// machine simultaneously without conflicts.
///
///   Debug:   HTTP=40400  WS=40401
///   Release: HTTP=40404  WS=40405
const int kDefaultHttpPort = kReleaseMode ? 40404 : 40400;
const int kDefaultWsPort = kReleaseMode ? 40405 : 40401;
