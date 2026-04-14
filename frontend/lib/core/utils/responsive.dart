import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

class Responsive {
  Responsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppDimensions.breakpointMobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointMobile &&
      MediaQuery.of(context).size.width < AppDimensions.breakpointTablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppDimensions.breakpointTablet;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? desktop;
    return mobile;
  }
}
