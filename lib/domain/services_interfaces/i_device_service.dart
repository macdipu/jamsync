import '../entities/device.dart';

abstract class IDeviceService {
  Future<Device> createLocalDevice({
    required DeviceRole role,
    int? port,
  });

  Device? get cachedDevice;
  Future<void> cacheLocalDevice(Device device);
}

