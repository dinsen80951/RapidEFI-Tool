import 'package:rapidefi/utils/config/config_model.dart';
import 'package:rapidefi/utils/config/models/device_properties/igpu_model.dart';
import 'package:rapidefi/utils/config/models/enums/brand_enum.dart';
import 'package:rapidefi/utils/config/models/enums/cpu_type_enum.dart';
import 'package:rapidefi/utils/config/models/enums/platform_type_enum.dart';
import 'package:rapidefi/utils/config/support/platform_properties.dart';

class IntelIgpuMemoryPolicy {
  IntelIgpuMemoryPolicy._();

  static const _supportedPlatforms = {
    'ivy_bridge',
    'haswell',
    'broadwell',
    'skylake',
    'kaby_lake',
    'coffee_lake_8th',
    'coffee_lake_9th',
    'comet_lake',
    'ice_lake',
  };

  static bool hasDrivenFramebuffer(ConfigModel model) =>
      _drivenFramebuffer(model) != null;

  static void applySurfaceDefault(ConfigModel model) {
    if (model.brand != Brand.microsoft) return;

    final framebuffer = _drivenFramebuffer(model);
    if (framebuffer == null) return;

    DevicePropertiesAccessor.setProperty(
      model,
      framebuffer.pciPath,
      framebuffer_stolenmem_30m,
    );
  }

  static IgpuPropertyModel? _drivenFramebuffer(ConfigModel model) {
    if (model.cpuType != CpuType.intel ||
        model.platformType == PlatformType.hedt ||
        !_supportedPlatforms.contains(model.platformCode)) {
      return null;
    }

    for (final device in model.deviceProperties.addList ?? const []) {
      for (final item in device.propertyItems) {
        final key = item.key?.trim().toLowerCase();
        if (key != 'aapl,ig-platform-id' && key != 'aapl,snb-platform-id') {
          continue;
        }
        if (!item.display || item.value?.trim().toUpperCase() == '11223344') {
          continue;
        }
        return device;
      }
    }
    return null;
  }
}
