import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_ble/flutter_bluetooth_serial_ble.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../apiService/apiService.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'model/models.dart';

class Sellpage extends StatefulWidget {
  final BluetoothDevice server;

  const Sellpage({required this.server});

  @override
  State<Sellpage> createState() => _SellpageState();
}

class _SellpageState extends State<Sellpage> {
  BluetoothConnection? connection;

  String _messageBuffer = '';
  String msg = "";

  String part1 = "";

  Set<String> Tags = {};
  Map<String, dynamic> TagData = {};

  final TextEditingController textEditingController =
      new TextEditingController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  bool mode = true;

  final invoiceController = TextEditingController();
  final olShopController = TextEditingController();

  String generateHmac(String secret, String data) {
    final key = utf8.encode(secret); // Convert secret key to bytes
    final bytes = utf8.encode(data); // Convert data to bytes
    final hmac = Hmac(sha256, key); // Create HMAC-SHA256 instance
    return hmac.convert(bytes).toString(); // Generate and return the hash
  }

  final secretKey = dotenv.env["SECRET_KEY"] ?? 'Not Found';

  // String url_single = 'https://2876-118-99-106-112.ngrok-free.app/api/item/item-sold/';
  String url_bulk =
      ApiService.baseUrl + '/ship-items'; //if problematic change this
  final TextEditingController searchController = TextEditingController();
  int? selectedInvoiceId;

  Invoice? selectedInvoice; // Keep track of the selected Invoice object

  List<SoldItem> _invoiceItems =
      []; // List to store items fetched for the invoice
  bool _isLoadingInvoiceItems = false; // Loading state
  @override
  void initState() {
    super.initState();
    // serialNumberController.addListener(controllerToText);
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });

      _sendMessage("r"); //if problematic change this
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverName = widget.server.name ?? "Unknown";
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ' + serverName + '...')
              : isConnected
                  ? Text('Connected with ' + serverName)
                  : Text('Disconnected with ' + serverName))),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: DropdownSearch<Invoice>(
                asyncItems: (String filter) => ApiService.fetchInvoice(filter),
                itemAsString: (Invoice invoice) => invoice.invoiceStr,
                onChanged: (Invoice? suggestion) async {
                  // Make onChanged async
                  setState(() {
                    selectedInvoice =
                        suggestion; // Store the selected Invoice object
                    selectedInvoiceId = suggestion?.id; // Store the ID
                    _invoiceItems = []; // Clear previous items
                    _isLoadingInvoiceItems = false; // Reset loading state
                  });

                  if (suggestion != null && suggestion.id != null) {
                    setState(() {
                      _isLoadingInvoiceItems = true; // Start loading
                    });
                    try {
                      final data =
                          await ApiService.fetchItemsByInvoice(suggestion.id!);
                      final List<dynamic> soldItemsJson =
                          data['sold_items'] ?? [];
                      setState(() {
                        _invoiceItems = soldItemsJson
                            .map((itemJson) => SoldItem.fromJson(itemJson))
                            .toList();
                        _isLoadingInvoiceItems =
                            false; // Stop loading on success
                      });
                      print(
                          "Fetched ${_invoiceItems.length} items for invoice ${suggestion.id}");
                    } catch (e) {
                      print("Error fetching invoice items: $e");
                      setState(() {
                        _isLoadingInvoiceItems = false; // Stop loading on error
                        _invoiceItems = []; // Clear items on error
                      });
                      Fluttertoast.showToast(
                        msg: "Failed to load invoice items: ${e.toString()}",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  }
                },
                selectedItem:
                    selectedInvoice, // Add this to show the selected invoice
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Search Invoice",
                    border: OutlineInputBorder(),
                  ),
                ),
                popupProps: PopupProps.dialog(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: "Type to search...",
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Text(
                selectedInvoiceId != null
                    ? 'Items in Invoice ${selectedInvoice?.invoiceStr ?? selectedInvoiceId}'
                    : 'Select an Invoice to see items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            _isLoadingInvoiceItems
                ? Center(
                    child:
                        CircularProgressIndicator()) // Show loading indicator
                : _invoiceItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Text(
                          selectedInvoiceId != null
                              ? 'No items found for this invoice.'
                              : '', // Only show message if invoice is selected
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics:
                            NeverScrollableScrollPhysics(), // Prevent nested scrolling issues
                        itemCount: _invoiceItems.length,
                        itemBuilder: (context, index) {
                          final item = _invoiceItems[index];
                          bool isTagExists = Tags.contains(
                              item.itemTag); // Check if tag exists

                          return ListTile(
                            title: Text(
                              "${item.itemSn} - ${item.itemType}",
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              "Tag: ${item.itemTag}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isTagExists
                                    ? Colors.green
                                    : Colors.black, // Highlight if tag exists
                              ),
                            ),
                            tileColor: isTagExists
                                ? Colors.green[50]
                                : null, // Optional background color
                          );
                        },
                      ),

            Text(selectedInvoiceId != null
                ? selectedInvoiceId.toString()
                : "No Invoice Selected"),
            Text("Received Non-Regitered RFID EPC:"),
            ListView.builder(
              shrinkWrap: true,
              itemCount: Tags.where((tag) {
                // Filter out tags that are already in invoiceItems
                return !_invoiceItems.any((item) => item.itemTag == tag);
              }).length,
              itemBuilder: (context, index) {
                String tag = Tags.where((tag) {
                  // Filter out tags that are already in invoiceItems
                  return !_invoiceItems.any((item) => item.itemTag == tag);
                }).toList()[index];

                return ListTile(
                  title: Center(
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                  trailing: GestureDetector(
                    onTap: () {
                      setState(() {
                        Tags.remove(tag);
                      });
                    },
                    child: Icon(Icons.delete),
                  ),
                );
              },
            ),

            // SizedBox(height: 10),

            // Padding(
            //     padding: const EdgeInsets.only(left: 10, right: 10),
            //     child: TextField(
            //       controller: invoiceController,
            //       decoration: InputDecoration(
            //           label: Text("Item Invoice"),
            //           border: OutlineInputBorder(),
            //           hintText: "Enter Invoice",
            //           hintStyle: TextStyle(
            //             color: Colors.grey,
            //           )),
            //     ),
            //   ),

            // SizedBox(height: 10),

            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 10),
            //   child: TextField(
            //     controller: olShopController,
            //     decoration: InputDecoration(
            //         label: Text("Online Shop"),
            //         border: OutlineInputBorder(),
            //         hintText: "Enter Shop",
            //         hintStyle: TextStyle(
            //           color: Colors.grey,
            //         )),
            //   ),
            // ),

            SizedBox(height: 10),

            ElevatedButton(
              onPressed: () async {
                if (selectedInvoiceId != null && Tags.isNotEmpty) {
                  Map<String, dynamic> data = {
                    "item_tags": Tags.toList(),
                  };
                  try {
                    await ApiService.updateInvoice(selectedInvoiceId!, data);
                    Fluttertoast.showToast(
                      msg: "Invoice updated successfully!",
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                    );
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: "Failed to update invoice: $e",
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                } else {
                  Fluttertoast.showToast(
                    msg: "Please select an invoice and add tags first.",
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                }
              },
              child: Text("Update Invoice"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
                onPressed: () {
                  setState(() {
                    Tags.clear();
                    msg = '';
                  });
                },
                child: Text("Clear RFID Data")),
            // const SizedBox(height: 10),
            // ElevatedButton(
            //         onPressed: () {
            //           if (isConnected) {
            //             mode = !mode;
            //             sendMessageCondition(mode);
            //             print(mode);
            //           }
            //         },
            //         child: Text("Change Mode")
            // ),
            // Text(mode ? "RFID Mode" : "QR Mode"),
          ],
        ),
      ),
    );
  }

  Future<void> sendData(String url, Map<String, dynamic> data) async {
    try {
      final apiUrl = "/api/item/ship-items";
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final requestSign = timestamp + apiUrl;
      final signature = generateHmac(secretKey, requestSign);

      // Convert the data map to a JSON string
      String jsonData = jsonEncode(data);
      print("JSON DATA: ${jsonData}");
      // Send the POST request
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Signature': signature,
          'Timestamp': timestamp,
          'Content-Type': 'application/json',
        },
        body: jsonData,
      );
      print(response.statusCode);
      print(response);
      // Check the response status code
      if (response.statusCode >= 200 && response.statusCode <= 299) {
        print('Request successful');
        print('Response body: ${response.body}');

        Fluttertoast.showToast(
          msg: "Data sent successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        print('Request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');

        Fluttertoast.showToast(
          msg: "Error ${response.statusCode} : ${response.body}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text)));
        await connection!.output.allSent;
        print("send data success!");
        setState(() {});
      } catch (e) {
        // Ignore error, but notify state
        print("ERROR: $e");
        setState(() {});
      }
    }
  }

  void _onDataReceived(Uint8List data) async {
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    String dataString = String.fromCharCodes(buffer).trim();

    // print(dataString);
    // print("LIST: $Tags");
    // int index = buffer.indexOf(13);
    if (dataString.isNotEmpty) {
      setState(() {
        // Tambahkan hanya jika belum ada dan bukan string kosong
        if (dataString.isNotEmpty && !Tags.contains(dataString)) {
          Tags.add(dataString);
        }
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }
}
