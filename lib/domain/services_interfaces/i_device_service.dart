import '../entities/device.dart';

abstract class IDeviceService {
  Future<Device> createLocalDevice({
    required DeviceRole role,
    int port = 51234,
  });

  Device? get cachedDevice;
  void cacheDevice(Device device);
}
