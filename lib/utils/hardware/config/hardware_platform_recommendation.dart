import 'package:rapidefi/utils/config/models/platform_info/pi_generic.dart';
import 'package:rapidefi/utils/config/presets/platform_profiles/platform_configs.dart';
import 'package:rapidefi/utils/config/services/config_service.dart';
import 'package:rapidefi/utils/config/support/macos_version.dart';
import 'package:rapidefi/utils/config/support/smbios_compatibility.dart';
import 'package:rapidefi/utils/hardware/config/hardware_platform_resolver.dart';

class HardwarePlatformRecommendation {
  const HardwarePlatformRecommendation({
    required this.macOSVersion,
    required this.darwinMajor,
    required this.supportDescription,
    this.smbios,
  });

  final String macOSVersion;
  final int darwinMajor;
  final String supportDescription;
  final PlatformInfoGeneric? smbios;
}

/// 使用已有平台资料中的 last_supported 为自动配置推荐系统和 SMBIOS。
class HardwarePlatformRecommendationResolver {
  const HardwarePlatformRecommendationResolver();

  Future<HardwarePlatformRecommendation> resolve(
    HardwarePlatformSelection selection,
  ) async {
    final platformModel = Configs().configsRepository.getPlatformModel(
          selection.cpuType,
          selection.platformType,
        );
    final platformEntry = platformModel?.platforms[selection.platformCode];
    final platformInfos = await ConfigService().getPlatformInfos(
      cpuType: selection.cpuType,
      platformType: selection.platformType,
    );
    final platformIndex =
        platformModel?.indexOfCode(selection.platformCode) ?? 0;
    final supportDescription = platformIndex >= 0 &&
            platformIndex < platformInfos.length
        ? platformInfos[platformIndex].lastSupported
        : '';
    final darwinMajor = highestDarwinMajor(supportDescription) ??
        MacOSVersions.defaultDarwinMajor;
    final smbios = SMBIOSCompatibility.recommendClosestForDarwinMajor(
      platformEntry?.smbiosOptions ?? const <PlatformInfoGeneric>[],
      darwinMajor,
    );

    return HardwarePlatformRecommendation(
      macOSVersion: MacOSVersions.labelFromDarwinMajor(darwinMajor),
      darwinMajor: darwinMajor,
      supportDescription: supportDescription,
      smbios: smbios,
    );
  }

  static int? highestDarwinMajor(String supportDescription) {
    final normalized = supportDescription.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    const namedVersions = <String, int>{
      'tahoe': 25,
      'sequoia': 24,
      'sonoma': 23,
      'ventura': 22,
      'monterey': 21,
      'big sur': 20,
      'bigsur': 20,
      'catalina': 19,
      'mojave': 18,
      'high sierra': 17,
      'highsierra': 17,
    };
    for (final entry in namedVersions.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }

    final versionMatches = RegExp(r'\b(10|1[1-9]|2[0-9])(?:\.(\d+))?')
        .allMatches(normalized);
    int? highest;
    for (final match in versionMatches) {
      final major = match.group(1) ?? '';
      final minor = match.group(2);
      final productVersion =
          major == '10' && minor != null ? '$major.$minor' : major;
      final darwinMajor =
          MacOSVersions.darwinMajorFromProductVersion(productVersion);
      if (highest == null || darwinMajor > highest) highest = darwinMajor;
    }
    return highest;
  }
}
