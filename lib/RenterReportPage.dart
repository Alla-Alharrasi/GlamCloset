import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RenterReportPage extends StatefulWidget {
  @override
  State<RenterReportPage> createState() => _RenterReportPageState();
}

class _RenterReportPageState extends State<RenterReportPage> {
  final DatabaseService _dbService = DatabaseService();
  bool isLoading = true;
  int totalDresses = 0;

  List<Map<String, dynamic>> clothesStats = [];

  @override
  void initState() {
    super.initState();
    _fetchClothesStats();
  }

  Future<void> _fetchClothesStats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _dbService.ordersStream().listen((orders) async {
      Map<String, Map<String, dynamic>> tempStats = {};
      int totalOrders = 0;

      // ---------- Count total orders for renter's clothes ----------
      orders.forEach((userId, userOrders) {
        if (userOrders is Map) {
          userOrders.forEach((orderId, orderData) {
            final items = orderData['items'] as Map<dynamic, dynamic>? ?? {};
            items.forEach((itemId, itemData) {
              final ownerId = itemData['ownerId'];
              if (ownerId == currentUser.uid) {
                totalOrders += 1;

                final name = itemData['name'] ?? '';
                if (!tempStats.containsKey(name)) {
                  tempStats[name] = {
                    'name': name,
                    'orders': 0,
                    'users': <String>{},
                  };
                }
                tempStats[name]!['orders'] += 1;
                tempStats[name]!['users'].add(userId);
              }
            });
          });
        }
      });

      // ---------- Count total clothes posted ----------
      final ref = FirebaseDatabase.instance.ref('rented_clothes');
      final snapshot = await ref.get();
      int totalClothesPosted = 0;
      if (snapshot.exists && snapshot.value is Map) {
        (snapshot.value as Map).forEach((key, value) {
          final cloth = Map<String, dynamic>.from(value);
          if (cloth['userId'] == currentUser.uid) totalClothesPosted++;
        });
      }

      // ---------- Update state ----------
      setState(() {
        clothesStats = tempStats.values.map((e) {
          return {
            'name': e['name'],
            'orders': e['orders'],
            'usersCount': (e['users'] as Set<String>).length,
          };
        }).toList();

        totalDresses = totalClothesPosted; // total posted clothes
        isLoading = false;
      });
    });
  }


  Future<void> _generatePdf(BuildContext context) async {
    if (clothesStats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No clothes stats to include in the PDF.")),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Text('Clothes Stats Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Cloth Name', 'Number of Orders', 'Number of Users'],
            data: clothesStats.map((c) {
              return [c['name'], c['orders'], c['usersCount']];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ PDF downloaded successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey.shade100;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        elevation: 1,
        leading: BackButton(color: textColor),
        title: Text(
          "Renter Clothes Stats",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // ---------- Total Dresses Card ----------
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.green.shade400,
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: const Text(
                  "Total Dresses Added",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white),
                ),
                trailing: Text(
                  "$totalDresses",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.white),
                ),
              ),
            ),
            // ---------- Clothes Stats List ----------
            Expanded(
              child: ListView.builder(
                itemCount: clothesStats.length,
                itemBuilder: (context, index) {
                  final item = clothesStats[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: cardColor,
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        item['name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text("Number of Orders: ${item['orders']}"),
                          Text("Number of Users: ${item['usersCount']}"),
                        ],
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
}
