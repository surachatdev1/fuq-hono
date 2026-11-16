import 'package:web/web.dart' as web;

void openExternal(Uri url) {
  web.window.open(url.toString(), '_blank', 'noopener,noreferrer');
}
