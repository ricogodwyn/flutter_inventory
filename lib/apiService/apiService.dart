import 'package:crypto/crypto.dart';
import 'package:flutter_bluetooth_serial_example/model/models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const baseUrl = "https://h808khjv-5000.asse.devtunnels.ms/api/item";

class ApiService {
  static final String secretKey = dotenv.env["SECRET_KEY"] ?? 'Not Found';

  static String generateHmac(String secret, String data) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  static Future<List<Invoice>> fetchInvoice(String search) async {
    try {
      final apiUrl = "/api/item/get-invoices";
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final requestSign = timestamp + apiUrl;
      final signature = generateHmac(secretKey, requestSign);
      print(requestSign);
      final url = Uri.parse('$baseUrl/get-invoices').replace(queryParameters: {
        'search': search,
      });

      final response = await http.get(
        url,
        headers: {
          'Signature': signature,
          'Timestamp': timestamp,
          'Content-Type': 'application/json',
        },
        //1746030317859/api/item/get-invoices
        //1746030356375/api/item/get-types
        //1746030505450/api/item/get-invoices?search=vb
      );

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        List data = json.decode(response.body);
        return data.map((json) => Invoice.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch invoices. Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  //https://h808khjv-5000.asse.devtunnels.ms/api/item/get-invoice-items/8
  static Future<Map<String, dynamic>> fetchItemsByInvoice(int id) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final apiUrl = "/api/item/get-invoice-items/$id";
      final requestSign = timestamp + apiUrl;
      final signature = generateHmac(secretKey, requestSign);

      final url = Uri.parse('$baseUrl/get-invoice-items/$id');
      print(url);
      final response = await http.get(
        url,
        headers: {
          'Signature': signature,
          'Timestamp': timestamp,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load items. Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> updateInvoice(int id, Map<String, dynamic> data) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final apiUrl = "/api/item/ship-items/$id";
      final requestSign = timestamp + apiUrl;
      final signature = generateHmac(secretKey, requestSign);

      final uri = Uri.parse('$baseUrl/ship-items/$id');

      final response = await http.patch(
        uri,
        headers: {
          'Signature': signature,
          'Timestamp': timestamp,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Successfully updated');
      } else {
        throw Exception(
            'Failed to update invoice. Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
