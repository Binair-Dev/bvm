class AppConstants {
  static const String appName = 'bVM';
  static const String version = '0.1.0';
  static const String packageName = 'com.bvm.mobile';

  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'B_nair';
  static const String authorEmail = 'van.bellinghen.brian@gmail.com';
  static const String githubUrl = 'https://github.com/Binair-Dev/bvm';
  static const String license = 'MIT';

  static const String orgName = 'bVM';
  static const String orgEmail = 'van.bellinghen.brian@gmail.com';

  static const String channelName = 'com.bvm.mobile/native';
  static const String eventChannelName = 'com.bvm.mobile/events';

  static const String ubuntuRootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';
  static const String rootfsAmd64 = '${ubuntuRootfsUrl}amd64.tar.gz';

  static String getRootfsUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return rootfsArm64;
      case 'arm':
        return rootfsArmhf;
      case 'x86_64':
        return rootfsAmd64;
      default:
        return rootfsArm64;
    }
  }
}
