import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_embedded/src/web_view_return_uri_source.dart';

void main() {
  group('WebViewReturnUriSource', () {
    test('pushes added URIs to the stream', () async {
      final source = WebViewReturnUriSource();
      final captured = <Uri>[];
      final subscription = source.uris.listen(captured.add);

      final uri = Uri.parse('https://payments.example.com/zenpay/app-return?merchantUniquePaymentId=1');
      source.addUri(uri);

      await Future<void>.delayed(Duration.zero);
      expect(captured, <Uri>[uri]);

      await subscription.cancel();
      await source.dispose();
    });

    test('ignores addUri after dispose', () async {
      final source = WebViewReturnUriSource();
      await source.dispose();

      expect(() => source.addUri(Uri.parse('https://example.com')), returnsNormally);
    });
  });
}
