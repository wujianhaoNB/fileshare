import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utilities for local network operations.
class NetworkUtils {
  NetworkUtils._();

  /// Finds all local IP addresses (excluding loopback).
  static Future<List<InternetAddress>> getLocalAddresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <InternetAddress>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        addresses.add(addr);
      }
    }
    return addresses;
  }

  /// Gets the primary local IP address.
  static Future<String?> getLocalIp() async {
    final addresses = await getLocalAddresses();
    if (addresses.isEmpty) return null;
    return addresses.first.address;
  }

  /// Computes the /24 subnet range for a given IP.
  static List<String> getSubnetRange(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return [];
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final results = <String>[];
    // Scan common ranges: .1 - .254
    for (var i = 1; i <= 254; i++) {
      results.add('$prefix.$i');
    }
    return results;
  }

  /// Probes a single IP:port to see if it's reachable.
  static Future<bool> probeHost(String ip, int port, {Duration timeout = const Duration(milliseconds: 200)}) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Discovers the local device's hostname.
  static String get hostname {
    if (kIsWeb) return 'Web Browser';
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Unknown Device';
    }
  }
}
