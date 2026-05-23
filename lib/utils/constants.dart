import 'dart:ui';

class AppConstants {
  static const String appName = 'Flutter PowerPoint Pro';
  static const String appVersion = '1.0.0';

  static const Size defaultSlideSize = Size(960, 540);
  static const Size widescreenSlideSize = Size(1280, 720);
  static const Size standardSlideSize = Size(720, 540);

  static const double defaultFontSize = 18.0;
  static const double minZoom = 0.1;
  static const double maxZoom = 5.0;

  static const int maxUndoHistory = 200;
  static const int maxSlides = 1000;

  static const List<String> supportedImageFormats = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.svg'];
  static const List<String> supportedVideoFormats = ['.mp4', '.avi', '.mov', '.wmv'];

  static const Color powerPointRed = Color(0xFFB7472A);
  static const Color powerPointBlue = Color(0xFF4472C4);
  static const Color powerPointGreen = Color(0xFF70AD47);
  static const Color powerPointOrange = Color(0xFFED7D31);
}
