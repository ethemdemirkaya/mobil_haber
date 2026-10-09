import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pusula_news/core/ai/openrouter_client.dart';

http.Response _ok(String content) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'choices': [
          {
            'message': {'content': content}
          }
        ],
      })),
      200,
    );

http.Response _err(int code, [String? message]) => http.Response(
      jsonEncode({
        'error': {'message': message ?? 'hata $code'}
      }),
      code,
    );

void main() {
  Future<(String, List<String>)> run(
      Map<String, http.Response Function()> byModel) async {
    final tried = <String>[];
    final client = OpenRouterClient(
      httpClient: MockClient((req) async {
        final model = (jsonDecode(req.body) as Map)['model'] as String;
        tried.add(model);
        return byModel[model]!();
      }),
    );
    final out = await client.chat(
      apiKey: 'k',
      model: 'a:free',
      fallbackModels: const ['a:free', 'b:free', 'c:free'],
      systemPrompt: 's',
      userPrompt: 'u',
    );
    return (out, tried);
  }

  test('kaldırılmış (404) ve kotası dolmuş (429) modeli atlar', () async {
    final (out, tried) = await run({
      'a:free': () => _err(404),
      'b:free': () => _err(429),
      'c:free': () => _ok('tamam'),
    });
    expect(out, 'tamam');
    expect(tried, ['a:free', 'b:free', 'c:free']);
  });

  test('boş içerikte sıradaki modele geçer', () async {
    final (out, tried) = await run({
      'a:free': () => _ok('  '),
      'b:free': () => _ok('dolu'),
    });
    expect(out, 'dolu');
    expect(tried, ['a:free', 'b:free']);
  });

  test('anahtar hatasında (401) diğer modelleri denemez', () async {
    final tried = <String>[];
    final client = OpenRouterClient(
      httpClient: MockClient((req) async {
        tried.add((jsonDecode(req.body) as Map)['model'] as String);
        return _err(401);
      }),
    );
    await expectLater(
      client.chat(
        apiKey: 'k',
        model: 'a:free',
        fallbackModels: const ['b:free'],
        systemPrompt: 's',
        userPrompt: 'u',
      ),
      throwsA(isA<OpenRouterException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(tried, ['a:free']);
  });

  test('hepsi başarısızsa son hatayı fırlatır', () async {
    await expectLater(
      run({'a:free': () => _err(429), 'b:free': () => _err(503), 'c:free': () => _err(404)}),
      throwsA(isA<OpenRouterException>()
          .having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('isteklerde muhakeme kapalı gönderilir', () async {
    Map<String, dynamic>? body;
    final client = OpenRouterClient(
      httpClient: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _ok('Merhaba, ben Pusula.');
      }),
    );
    await client.chat(apiKey: 'k', model: 'a', systemPrompt: 's', userPrompt: 'u');
    expect(body!['reasoning'], {'enabled': false});
  });

  test('metne sızan muhakemeyi reddedip sıradaki modele geçer', () async {
    final (out, tried) = await run({
      'a:free': () => _ok("Here's a thinking process:\n1. **Analyze User Request**"),
      'b:free': () => _ok('Merhaba, ben Pusula. Bugün gündemde...'),
    });
    expect(out, startsWith('Merhaba'));
    expect(tried, ['a:free', 'b:free']);
  });

  test('<think> bloğu ayıklanır', () async {
    final (out, _) = await run({
      'a:free': () => _ok('<think>kullanıcı brifing istiyor…</think>\nMerhaba.'),
    });
    expect(out, 'Merhaba.');
  });

  test('muhakemesi kapatılamayan model parametresiz yeniden denenir', () async {
    final bodies = <Map>[];
    final client = OpenRouterClient(
      httpClient: MockClient((req) async {
        final b = jsonDecode(req.body) as Map;
        bodies.add(b);
        return b.containsKey('reasoning')
            ? _err(400, 'Reasoning is mandatory for this endpoint')
            : _ok('Tamam.');
      }),
    );
    final out = await client.chat(
        apiKey: 'k', model: 'a', systemPrompt: 's', userPrompt: 'u');
    expect(out, 'Tamam.');
    expect(bodies, hasLength(2));
  });

  test('Türkçe yanıt muhakeme sayılmaz', () {
    expect(OpenRouterClient.looksLikeLeakedReasoning('Merhaba, ben Pusula.'),
        isFalse);
    expect(OpenRouterClient.looksLikeLeakedReasoning('{"score": 10}'), isFalse);
    expect(OpenRouterClient.looksLikeLeakedReasoning('Okay, let me think.'),
        isTrue);
  });
}
