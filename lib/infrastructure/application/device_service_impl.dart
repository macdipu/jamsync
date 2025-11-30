import 'dart:io';
import 'dart:isolate';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/device.dart';
import '../../domain/services_interfaces/i_device_service.dart';

class DeviceServiceImpl implements IDeviceService {
  DeviceServiceImpl({AppLogger? logger}) : _logger = logger ?? AppLogger();

  final AppLogger _logger;
  Device? _cachedDevice;

  @override
  Device? get cachedDevice => _cachedDevice;

  @override
  void cacheDevice(Device device) {
    _cachedDevice = device;
  }

  @override
  Future<Device> createLocalDevice({required DeviceRole role, int port = 51234}) async {
    if (_cachedDevice != null && _cachedDevice!.role == role) {
      return _cachedDevice!;
    }

    final hostname = Platform.localHostname.isEmpty
        ? 'jamSync-${DateTime.now().millisecondsSinceEpoch}'
        : Platform.localHostname;

    final ip = await _resolveLocalIp();

    final device = Device(
      id: '$hostname-${DateTime.now().microsecondsSinceEpoch}',
      name: hostname,
      ip: ip,
      port: port,
      role: role,
      isLocal: true,
    );
    _cachedDevice = device;
    return device;
  }

  Future<String> _resolveLocalIp() async {
    return Isolate.run(() async {
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: true,
          type: InternetAddressType.IPv4,
        );
        final resolved = interfaces
            .expand((iface) => iface.addresses)
            .firstWhere(
              (addr) => !addr.isLoopback && addr.type == InternetAddressType.IPv4,
              orElse: () => interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty
                  ? interfaces.first.addresses.first
                  : InternetAddress.loopbackIPv4,
            );
        return resolved.address;
      } catch (error, stackTrace) {
        _logger.error('Failed to resolve local IP, falling back to loopback', error, stackTrace);
        return InternetAddress.loopbackIPv4.address;
      }
    });
  }
}
