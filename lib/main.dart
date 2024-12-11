import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'enums.dart';
import 'helpers.dart';
import 'models.dart';

class EpsonEPOS {
  static const MethodChannel _channel = const MethodChannel('epson_epos');

  static EpsonEPOSHelper _eposHelper = EpsonEPOSHelper();

  static bool _isPrinterPlatformSupport({bool throwError = false}) {
    if (Platform.isAndroid) return true;
    if (throwError) {
      throw PlatformException(
          code: "platformNotSupported", message: "Device not supported");
    }
    return false;
  }

  static Future<List<EpsonPrinterModel>?> onDiscovery({
    EpsonEPOSPortType type = EpsonEPOSPortType.ALL,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isPrinterPlatformSupport(throwError: true)) return null;

    String printType = _eposHelper.getPortType(type);
    final Map<String, dynamic> params = {"type": printType};

    try {
      String? rep = await _channel
          .invokeMethod('onDiscovery', params)
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('Printer discovery timed out');
      });

      if (rep != null) {
        final response = EpsonPrinterResponse.fromRawJson(rep);
        List<dynamic> prs = response.content ?? [];

        if (prs.isNotEmpty) {
          return prs.map((e) {
            final modelName = e['model'];
            final modelSeries = _eposHelper.getSeries(modelName);
            return EpsonPrinterModel(
              ipAddress: e['ipAddress'],
              bdAddress: e['bdAddress'],
              macAddress: e['macAddress'],
              type: printType,
              model: modelName,
              series: modelSeries?.id,
              target: e['target'],
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      throw PlatformException(
          code: 'DISCOVERY_ERROR',
          message: 'Error discovering printers: ${e.toString()}');
    }
  }

  static Future<dynamic> onPrint(
      EpsonPrinterModel printer, List<Map<String, dynamic>> commands) async {
    final Map<String, dynamic> params = {
      "type": printer.type,
      "series": printer.series,
      "commands": commands,
      "target": printer.target
    };
    return await _channel.invokeMethod('onPrint', params);
  }

  static Future<dynamic> getPrinterSetting(EpsonPrinterModel printer) async {
    final Map<String, dynamic> params = {
      "type": printer.type,
      "series": printer.series,
      "target": printer.target
    };
    return await _channel.invokeMethod('getPrinterSetting', params);
  }

  static Future<dynamic> setPrinterSetting(EpsonPrinterModel printer,
      {int? paperWidth, int? printDensity, int? printSpeed}) async {
    final Map<String, dynamic> params = {
      "type": printer.type,
      "series": printer.series,
      "paper_width": paperWidth,
      "print_density": printDensity,
      "print_speed": printSpeed,
      "target": printer.target
    };
    return await _channel.invokeMethod('setPrinterSetting', params);
  }
}
