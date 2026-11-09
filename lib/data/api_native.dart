import 'hono.dart';
import 'wire.dart';

HonoApi createApi(Map<String, dynamic> material) =>
    HonoApi(WireCodec(material));
