/// Web [AppRecaptchaClient]: `recaptcha_enterprise_flutter` only implements
/// Android/iOS, so this loads Google's `enterprise.js` directly and calls
/// `grecaptcha.enterprise.execute` via `dart:js_interop` — same low-level
/// interop style as `zenpay_flutter`'s `checkout_presenter_web.dart`
/// (raw `@JS()` externals, no `package:web` dependency).
///
/// See https://cloud.google.com/recaptcha/docs/instrument-web-pages.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client.dart';

/// Fetches the web [AppRecaptchaClient] for [siteKey]: loads `enterprise.js`
/// for [siteKey] and waits for `grecaptcha.enterprise` to be ready.
Future<AppRecaptchaClient> fetchAppRecaptchaClient(String siteKey) async {
  await _loadEnterpriseScript(siteKey);
  await _whenReady();
  return _WebAppRecaptchaClient(siteKey);
}

final class _WebAppRecaptchaClient implements AppRecaptchaClient {
  _WebAppRecaptchaClient(this._siteKey);
  final String _siteKey;

  @override
  Future<String> execute(String action) async {
    final token = await _grecaptchaEnterpriseExecute(_siteKey, _ExecuteOptions(action: action)).toDart;
    return token.toDart;
  }
}

/// Loads `enterprise.js?render=<siteKey>` into `<head>`, once per [siteKey] —
/// a second call with the same key reuses the same in-flight/completed load.
Future<void> _loadEnterpriseScript(String siteKey) {
  final existing = _scriptLoads[siteKey];
  if (existing != null) return existing.future;

  final completer = Completer<void>();
  _scriptLoads[siteKey] = completer;

  final script = _createElement('script') as _ScriptElement
    ..src = 'https://www.google.com/recaptcha/enterprise.js?render=$siteKey'
    ..async = true
    // The `completer.complete` tearoff looks like the obvious fix for
    // unnecessary_lambdas here, but dart2js rejects it: `Completer.complete`'s
    // `FutureOr<void>?` parameter is not a valid `toJS` function signature.
    // ignore: unnecessary_lambdas
    ..onload = (() => completer.complete()).toJS;
  _documentHead.append(script);

  return completer.future;
}

final _scriptLoads = <String, Completer<void>>{};

/// Resolves once `grecaptcha.enterprise` has finished its own internal setup
/// (script `onload` alone is not sufficient — see Google's docs above).
Future<void> _whenReady() {
  final completer = Completer<void>();
  // Same dart2js `toJS` restriction as `_loadEnterpriseScript`'s `onload`.
  // ignore: unnecessary_lambdas
  _grecaptchaEnterpriseReady((() => completer.complete()).toJS);
  return completer.future;
}

@JS('document.head')
external _Element get _documentHead;

@JS('document.createElement')
external JSObject _createElement(String tagName);

extension type _Element(JSObject _) implements JSObject {
  external void append(JSObject child);
}

extension type _ScriptElement(JSObject _) implements JSObject {
  external String get src;
  external set src(String value);
  external bool get async;
  external set async(bool value);
  external JSFunction? get onload;
  external set onload(JSFunction? value);
}

@JS('grecaptcha.enterprise.ready')
external void _grecaptchaEnterpriseReady(JSFunction callback);

@JS('grecaptcha.enterprise.execute')
external JSPromise<JSString> _grecaptchaEnterpriseExecute(String siteKey, _ExecuteOptions options);

extension type _ExecuteOptions._(JSObject _) implements JSObject {
  external factory _ExecuteOptions({String action});
}
