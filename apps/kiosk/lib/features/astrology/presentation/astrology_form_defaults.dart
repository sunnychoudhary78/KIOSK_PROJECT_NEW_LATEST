import 'package:flutter/material.dart';

/// Shared defaults for astrology birth forms (New kundali / New reading).
abstract final class AstrologyFormDefaults {
  static DateTime get dob => DateTime(1995, 1, 1);
  static DateTime get groomDob => DateTime(1992, 1, 1);
  static DateTime get brideDob => DateTime(1995, 1, 1);
  static const TimeOfDay birthTime = TimeOfDay(hour: 12, minute: 0);
  static const String gender = 'female';
  static const String chartStyle = 'north';
  static const String selectedChartKey = 'RasiD1';
}
