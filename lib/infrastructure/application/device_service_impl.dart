import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/device.dart';
import '../../domain/services_interfaces/i_device_service.dart';

class DeviceServiceImpl implements IDeviceService {
  DeviceServiceImpl({AppLogger? logger}) : _logger = logger ?? AppLogger();

  final AppLogger _logger;
  Device? _cachedDevice;

  @override
  Future<Device> createLocalDevice({required DeviceRole role, int? port}) async {
    final hostname = Platform.localHostname.isEmpty
        ? 'jamSync-${DateTime.now().millisecondsSinceEpoch}'
        : Platform.localHostname;
    var ip = InternetAddress.loopbackIPv4.address;
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
      ip = resolved.address;
    } catch (error, stackTrace) {
      ip = InternetAddress.loopbackIPv4.address;
      _logger.warn('Failed to resolve IP, fallback to loopback');
      _logger.error('Resolution error', error, stackTrace);
    }
    final device = Device(
      id: const Uuid().v4(),
      name: hostname,
      ip: ip,
      port: port ?? 51234,
      role: role,
      isLocal: true,
    );
    await cacheLocalDevice(device);
    return device;
  }

  @override
  Future<void> cacheLocalDevice(Device device) async {
    _cachedDevice = device;
  }

  @override
  Device? get cachedDevice => _cachedDevice;
}

