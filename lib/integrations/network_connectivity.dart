import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class NetworkConnectivity {
  final InternetConnection _connectionChecker = InternetConnection();

  Stream<bool> get connectivityStream => 
      _connectionChecker.onStatusChange.map(
        (status) => status == InternetStatus.connected,
      );

  Future<bool> get isConnected async => 
      await _connectionChecker.hasInternetAccess;
}