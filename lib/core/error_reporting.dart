import 'dart:ui';

import 'package:flutter/material.dart';

import 'startup_error.dart';

/// Stable error codes and code-location stacks, without exception values,
/// database arguments, credentials or financial records in runtime logs.
void configureErrorReporting(VoidCallback retry) {
  FlutterError.onError = (details) {
    debugPrint('SSS_FRAMEWORK_ERROR:${details.exception.runtimeType}');
    debugPrintStack(stackTrace: details.stack, maxFrames: 8);
  };
  ErrorWidget.builder = (_) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFFF4F7FB),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'SSS Khatabook could not display this screen.\nClose and reopen the app. Saved records have not been deleted.\nSupport code: SSS-UI',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF122334), fontSize: 18),
          ),
        ),
      ),
    ),
  );
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('SSS_ASYNC_ERROR:${error.runtimeType}');
    debugPrintStack(stackTrace: stack, maxFrames: 8);
    runApp(StartupErrorApp(onRetry: retry));
    return true;
  };
}
