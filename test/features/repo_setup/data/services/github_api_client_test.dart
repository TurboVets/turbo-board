// test/features/repo_setup/data/services/github_api_client_test.dart
//
// Test summary:
// - graphql() returns the `data` map on a 200 with no errors.
// - graphql() throws when the response contains a non-empty `errors` array.
// - graphql() throws on a non-200 status.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';

import 'github_api_client_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late GithubApiClient client;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    client = GithubApiClient(dio: dio);
  });

  Response<Map<String, dynamic>> resp(Map<String, dynamic>? data, {int status = 200}) => Response(
    requestOptions: RequestOptions(path: '/graphql'),
    statusCode: status,
    data: data,
  );

  test('returns data on success', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
      (_) async => resp({
        'data': {
          'search': <String, dynamic>{'nodes': <dynamic>[]},
        },
      }),
    );

    final data = await client.graphql('query{}', const {});

    expect(data, containsPair('search', isA<Map<String, dynamic>>()));
  });

  test('throws on GraphQL errors array', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
      (_) async => resp({
        'errors': [
          {'message': 'Bad credentials'},
        ],
      }),
    );

    expect(() => client.graphql('query{}', const {}), throwsA(isA<Exception>()));
  });

  test('throws on non-200', () async {
    when(
      dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data')),
    ).thenAnswer((_) async => resp(null, status: 401));

    expect(() => client.graphql('query{}', const {}), throwsA(isA<Exception>()));
  });
}
