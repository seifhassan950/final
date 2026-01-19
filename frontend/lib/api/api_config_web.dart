import 'dart:html' as html;

import 'api_config_impl.dart';

class ApiConfigImpl implements ApiConfigBase {
  @override
  String get origin => html.window.location.origin;
}
