export 'platform_download_stub.dart'
    if (dart.library.html) 'platform_download_web.dart'
    if (dart.library.io) 'platform_download_io.dart';
