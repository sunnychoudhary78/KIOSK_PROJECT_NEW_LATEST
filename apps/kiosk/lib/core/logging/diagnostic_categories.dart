import 'package:skp_kiosk/core/logging/app_logger.dart';

/// Stable category / event helpers for Admin diagnostic logs.
abstract final class Diag {
  static const printer = 'printer';
  static const astrology = 'astrology';
  static const shutter = 'shutter';

  static void printerInfo(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'info',
        category: printer,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void printerWarn(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'warn',
        category: printer,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void printerError(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'error',
        category: printer,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void astrologyInfo(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'info',
        category: astrology,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void astrologyError(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'error',
        category: astrology,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void shutterInfo(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'info',
        category: shutter,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void shutterWarn(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'warn',
        category: shutter,
        event: event,
        message: message,
        metadata: metadata,
      );

  static void shutterError(
    String event,
    String message, [
    Map<String, dynamic>? metadata,
  ]) =>
      AppLogger.log(
        level: 'error',
        category: shutter,
        event: event,
        message: message,
        metadata: metadata,
      );
}
