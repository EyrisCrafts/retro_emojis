import 'dart:typed_data';
import 'package:http/http.dart' as http;

class Utils {
  static Future<Uint8List> downloadMP4File(String url) async {
    // Make a GET request to the provided URL
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // Convert the response body (file content) to Uint8List
      final uint8List = response.bodyBytes;
      return uint8List;
    } else {
      // If the request fails, throw an exception or handle the error accordingly
      throw Exception('Failed to download MP4 file: ${response.statusCode}');
    }
  }
}
