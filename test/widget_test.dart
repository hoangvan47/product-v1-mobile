import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  test('Mini app host widget can be instantiated', () {
    const widget = MiniAppHost();
    expect(widget, isA<MiniAppHost>());
  });
}
