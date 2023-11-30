import "dart:convert";
import "package:http/http.dart" as http;

class Session {
  Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> cookies = {};

  Future<dynamic> post(String url, dynamic data) async {
    try {
      http.Response response = await http.post(Uri.parse(url),
          body: json.encode(data), headers: headers);

      final int statusCode = response.statusCode;
      switch (statusCode) {
        case 200:
          return json.decode(utf8.decode(response.bodyBytes));
        default:
          throw Exception(response.reasonPhrase);
      }
    } on Exception catch (_) {
      rethrow;
    }
  }
}
