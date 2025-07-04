import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExchangeRates {
  /// Obtiene el tipo de cambio del BCV (Banco Central de Venezuela)
  /// Devuelve el valor en VES (Bolívares) por 1 USD
  /// Si hay un error, devuelve 1.0 como valor por defecto
  static Future<double> getBCVExchangeRate() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://pydolarve.org/api/v1/dollar?page=alcambio&format_date=default&rounded_price=true'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bcvRate = data['monitors']['bcv']['price'];
        if (bcvRate != null) {
          return bcvRate.toDouble();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el tipo de cambio: $e');
      }
    }
    return 1.0; // Valor por defecto si no se puede obtener el tipo de cambio
  }
}