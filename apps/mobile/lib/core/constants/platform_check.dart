import 'platform_check_io.dart' if (dart.library.html) 'platform_check_stub.dart' as platform_check_impl;

bool get isMacOS => platform_check_impl.isMacOS;
