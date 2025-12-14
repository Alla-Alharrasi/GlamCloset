import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RentalsReportPage extends StatefulWidget {
  @override
  State<RentalsReportPage> createState() => _RentalsReportPageState();
}

class _RentalsReportPageState extends State<RentalsReportPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> rentalHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRentalHistory();
  }

  Future<void> _fetchRentalHistory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _dbService.ordersStream().listen((orders) {
      List<Map<String, dynamic>> rentals = [];

      orders.forEach((userId, userOrders) {
        if (userOrders is Map) {
          userOrders.forEach((orderId, orderData) {
            final items = orderData['items'] as Map<dynamic, dynamic>? ?? {};
            String status = orderData['status'] ?? '';

            // Convert Pending → Completed
            if (status.toLowerCase() == 'pending') {
              status = 'Completed';
            }

            if (status.toLowerCase() == 'completed' ||
                status.toLowerCase() == 'canceled') {
              items.forEach((itemId, itemData) {
                rentals.add({
                  "id": orderId,
                  "item": itemData['name'] ?? '',
                  "date": orderData['orderDate'] ?? '',
                  "price": "${itemData['price'] ?? 0} OMR",
                  "status": status,
                });
              });
            }
          });
        }
      });

      setState(() {
        rentalHistory = rentals;
        isLoading = false;
      });
    });
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'completed') return Colors.green;
    if (status.toLowerCase() == 'canceled') return Colors.red;
    return Colors.grey;
  }

  Future<void> _generatePdf(BuildContext context) async {
    if (rentalHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No rentals to include in the PDF.")),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text('Rentals Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['ID', 'Item', 'Date', 'Price', 'Status'],
            data: rentalHistory.map((r) {
              return [
                r['id'] ?? '',
                r['item'] ?? '',
                r['date'] ?? '',
                r['price'] ?? '',
                r['status'] ?? ''
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ PDF downloaded successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey.shade100;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final appBarColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    int totalRentals = rentalHistory.length;

    int totalPrice = rentalHistory.fold(0, (sum, item) {
      return sum + int.tryParse(item['price']?.split(' ')[0] ?? '0')!;
    });

    // NEW → total number of clothes
    int totalClothes = rentalHistory.length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: BackButton(color: textColor),
        backgroundColor: appBarColor,
        elevation: 1,
        title: Text(
          "Rentals Report",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard(
                    "Total Rentals", "$totalRentals", cardColor),
                _buildSummaryCard(
                    "Total Price", "$totalPrice OMR", cardColor),

                // UPDATED CARD → Shows number of dresses
                _buildSummaryCard(
                    "Clothes", "$totalClothes Dresses", cardColor),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Rental History (Completed & Canceled)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: rentalHistory.length,
                itemBuilder: (context, index) {
                  final rental = rentalHistory[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color:
                    rental['status']!.toLowerCase() == 'canceled'
                        ? Colors.grey.shade300
                        : cardColor,
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        rental['item']!,
                        style:
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text("Rental ID: ${rental['id']}"),
                          Text("Dates: ${rental['date']}"),
                          Text("Price: ${rental['price']}"),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                              rental['status']!)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rental['status']!,
                          style: TextStyle(
                            color:
                            _getStatusColor(rental['status']!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: () => _generatePdf(context),
                child: const Text("Download PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color cardColor) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
