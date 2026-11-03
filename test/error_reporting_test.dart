import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_khata_app/core/error_reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('framework error logging excludes exception values', () {
    final previousHandler = FlutterError.onError;
    final previousBuilder = ErrorWidget.builder;
    final previousAsyncHandler = PlatformDispatcher.instance.onError;
    final previousPrint = debugPrint;
    final output = <String>[];
    try {
      debugPrint = (String? message, {int? wrapWidth}) {
        output.add(message ?? '');
      };
      configureErrorReporting(() {});
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('PRIVATE_CUSTOMER_AMOUNT_12345'),
          stack: StackTrace.current,
        ),
      );
      expect(output.join('\n'), contains('SSS_FRAMEWORK_ERROR'));
      expect(
        output.join('\n'),
        isNot(contains('PRIVATE_CUSTOMER_AMOUNT_12345')),
      );
    } finally {
      FlutterError.onError = previousHandler;
      ErrorWidget.builder = previousBuilder;
      PlatformDispatcher.instance.onError = previousAsyncHandler;
      debugPrint = previousPrint;
    }
  });
}
