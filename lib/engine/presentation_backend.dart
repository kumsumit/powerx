import 'dart:io';

import 'package:flutter/services.dart';

import '../models/presentation.dart';
import 'pptx_exporter.dart';
import 'pptx_importer.dart';

class OfficeEngineUnavailableException implements Exception {
  const OfficeEngineUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfficeEngineInstallUnavailableException
    extends OfficeEngineUnavailableException {
  const OfficeEngineInstallUnavailableException(super.message);
}

abstract class PresentationBackend {
  Future<Presentation> open(String filePath);

  Future<void> save(Presentation presentation, String filePath);
}

abstract class OfficeCompatibilityEngine {
  Future<bool> get isAvailable;

  Future<void> ensureAvailable();

  Future<LegacyPptConversion> convertLegacyPpt(String pptPath);
}

class HybridPresentationBackend implements PresentationBackend {
  HybridPresentationBackend({
    PptxExporter? pptxExporter,
    OfficeCompatibilityEngine? officeEngine,
  }) : _pptxExporter = pptxExporter ?? PptxExporter(),
       _officeEngine = officeEngine ?? _defaultOfficeEngine();

  final PptxExporter _pptxExporter;
  final OfficeCompatibilityEngine _officeEngine;

  static OfficeCompatibilityEngine _defaultOfficeEngine() {
    if (Platform.isAndroid) return AndroidOnDemandOfficeEngine();
    return LocalOfficeCompatibilityEngine();
  }

  @override
  Future<Presentation> open(String filePath) async {
    final extension = _extensionOf(filePath);
    if (extension == 'ppt') {
      await _officeEngine.ensureAvailable();
      final conversion = await _officeEngine.convertLegacyPpt(filePath);
      try {
        return PptxImporter().importConvertedLegacyPpt(
          conversion.pptxPath,
          displayFilePath: filePath,
        );
      } finally {
        await conversion.dispose();
      }
    }

    return PptxImporter().import(filePath);
  }

  @override
  Future<void> save(Presentation presentation, String filePath) async {
    final extension = _extensionOf(filePath);
    if (extension == 'ppt') {
      await _officeEngine.ensureAvailable();
      throw const OfficeEngineUnavailableException(
        'Saving directly to legacy .ppt requires the native Office Engine save bridge.',
      );
    }

    await _pptxExporter.export(presentation, filePath);
  }

  String _extensionOf(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot == -1 || dot == filePath.length - 1) return '';
    return filePath.substring(dot + 1).toLowerCase();
  }
}

class LocalOfficeCompatibilityEngine implements OfficeCompatibilityEngine {
  LocalOfficeCompatibilityEngine({List<String>? executableCandidates})
    : _legacyPptConverter = LegacyPptConverter(
        executableCandidates: executableCandidates,
      );

  final LegacyPptConverter _legacyPptConverter;

  @override
  Future<LegacyPptConversion> convertLegacyPpt(String pptPath) {
    return _legacyPptConverter.convert(pptPath);
  }

  @override
  Future<bool> get isAvailable async {
    if (Platform.isAndroid || Platform.isIOS) {
      return false;
    }

    for (final executable
        in _legacyPptConverter.executableCandidatesForPlatform()) {
      if (await _canRun(executable)) return true;
    }
    return false;
  }

  @override
  Future<void> ensureAvailable() async {
    if (await isAvailable) return;

    if (Platform.isAndroid || Platform.isIOS) {
      throw const OfficeEngineUnavailableException(
        'Office Compatibility Engine is not installed on this device.',
      );
    }

    throw const OfficeEngineUnavailableException(
      'LibreOffice or OpenOffice is required for complete legacy .ppt support.',
    );
  }

  Future<bool> _canRun(String executable) async {
    try {
      final result = await Process.run(executable, ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

class AndroidOnDemandOfficeEngine implements OfficeCompatibilityEngine {
  AndroidOnDemandOfficeEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('powerx/office_engine');

  final MethodChannel _channel;

  @override
  Future<bool> get isAvailable async {
    final installed = await _channel.invokeMethod<bool>('isInstalled');
    return installed ?? false;
  }

  @override
  Future<void> ensureAvailable() async {
    final bool? installed;
    try {
      installed = await _channel.invokeMethod<bool>('ensureInstalled');
    } on PlatformException catch (e) {
      if (e.code == 'engine_install_failed') {
        final message = e.message ?? '';
        if (message.contains('not owned')) {
          throw const OfficeEngineInstallUnavailableException(
            'Office Compatibility Engine download is unavailable because this app was not installed from Play Store.',
          );
        }
        throw OfficeEngineUnavailableException(
          'Office Compatibility Engine install failed: $message',
        );
      }
      rethrow;
    }
    if (installed != true) {
      throw const OfficeEngineUnavailableException(
        'Office Compatibility Engine is not installed on this device.',
      );
    }
  }

  @override
  Future<LegacyPptConversion> convertLegacyPpt(String pptPath) async {
    final pptxPath = await _channel.invokeMethod<String>(
      'convertLegacyPptToPptx',
      {'pptPath': pptPath},
    );
    if (pptxPath == null || pptxPath.isEmpty) {
      throw const OfficeEngineUnavailableException(
        'Office Compatibility Engine did not return a converted PPTX file.',
      );
    }
    return LegacyPptConversion(pptxPath);
  }

  Future<void> openDocument(String documentPath) async {
    await ensureAvailable();
    await _channel.invokeMethod<bool>(
      'openInOfficeEngine',
      {'documentPath': documentPath},
    );
  }
}
