// Test summary:
// - complete posts to /v1/chat/completions and returns choices[0].message.content
// - complete throws on a non-200 status
// - validateKey returns true on 200, false on 401, throws on 500
// - setKey sets/clears the Authorization: Bearer header
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/ai/data/services/ai_provider_kind.dart';
import 'package:turbo_board/features/ai/data/services/openai_api_client.dart';

import 'openai_api_client_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late OpenAiApiClient client;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    client = OpenAiApiClient(dio: dio);
  });

  Response<Map<String, dynamic>> chat(Map<String, dynamic>? data, {int status = 200}) => Response(
    requestOptions: RequestOptions(path: '/v1/chat/completions'),
    statusCode: status,
    data: data,
  );

  void stub(Response<Map<String, dynamic>> response) {
    when(
      dio.post<Map<String, dynamic>>('/v1/chat/completions', data: anyNamed('data')),
    ).thenAnswer((_) async => response);
  }

  test('provider is openai', () {
    expect(client.provider, AiProvider.openai);
  });

  test('complete returns message content', () async {
    stub(
      chat({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'hello world'},
          },
        ],
      }),
    );
    expect(await client.complete(prompt: 'hi'), 'hello world');
  });

  test('complete throws on non-200', () async {
    stub(chat(null, status: 429));
    expect(() => client.complete(prompt: 'hi'), throwsException);
  });

  test('validateKey true/false/throw', () async {
    stub(chat({'choices': []}, status: 200));
    expect(await client.validateKey(), isTrue);
    stub(chat(null, status: 401));
    expect(await client.validateKey(), isFalse);
    stub(chat(null, status: 500));
    expect(() => client.validateKey(), throwsException);
  });

  test('setKey sets and clears the bearer header', () {
    client.setKey('sk-test');
    expect(dio.options.headers['Authorization'], 'Bearer sk-test');
    client.setKey(null);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });
}
