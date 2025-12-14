import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class RenterNotificationsPage extends StatefulWidget {
  final String renterId;

  RenterNotificationsPage({required this.renterId});

  @override
  _RenterNotificationsPageState createState() =>
      _RenterNotificationsPageState();
}

class _RenterNotificationsPageState extends State<RenterNotificationsPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Notifications",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: StreamBuilder(
        stream: _db.child("notifications").child(widget.renterId).onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(
              child: Text(
                "No notifications found",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            );
          }

          final rawData = snapshot.data!.snapshot.value;
          if (rawData == null || rawData is! Map) {
            return Center(
              child: Text(
                "No notifications found",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            );
          }

          final notificationsMap = Map<dynamic, dynamic>.from(rawData);
          List<MapEntry<dynamic, dynamic>> notificationsList = notificationsMap.entries.toList();

          // Sort notifications by timestamp descending
          notificationsList.sort((a, b) {
            final aTime = DateTime.tryParse(a.value["timestamp"] ?? "") ?? DateTime.now();
            final bTime = DateTime.tryParse(b.value["timestamp"] ?? "") ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: notificationsList.length,
            itemBuilder: (context, index) {
              final item = notificationsList[index];
              final notification = Map<String, dynamic>.from(item.value);
              final notificationId = item.key.toString();
              return _buildNotificationCard(notification, notificationId, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map notification, String notificationId, bool isDark) {
    final clothingName = notification['clothing'] ?? 'N/A';
    final customerPhone = notification['customerPhone'] ?? 'N/A';
    final location = notification['location'] ?? 'N/A';
    final status = notification['status'] ?? 'pending';

    return Card(
      color: isDark ? Colors.grey[850] : Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.grey[800]!, Colors.grey[900]!]
                : [Colors.white, Colors.grey[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Outfit: $clothingName",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? Colors.pink[200] : Colors.deepPurple,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Please deliver the outfit to: Ginakom Office\nRented, please comply and deliver it to office within 2 days",
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 18, color: isDark ? Colors.blue[200] : Colors.blueGrey),
                SizedBox(width: 6),
                Text(
                  customerPhone,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.location_on, size: 18, color: isDark ? Colors.red[300] : Colors.redAccent),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (notification['dressImageBase64'] != null && notification['dressImageBase64'].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  base64Decode(notification['dressImageBase64']),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: status == 'delivered'
                  ? null
                  : () async {
                await _db
                    .child("notifications")
                    .child(widget.renterId)
                    .child(notificationId)
                    .update({'status': 'delivered'});

                final customerId = notification['customerId'];
                if (customerId != null) {
                  final newNotifRef = FirebaseDatabase.instance
                      .ref('customer_notifications/$customerId')
                      .push();
                  await newNotifRef.set({
                    'orderId': notificationId,
                    'clothing': notification['clothing'],
                    'renterEmail': notification['renterEmail'],
                    'renterPhone': notification['renterPhone'],
                    'renterLocation': notification['renterLocation'],
                    'dressImageBase64': notification['dressImageBase64'] ?? '',
                    'status': 'pending',
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to delivered!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: Icon(Icons.check_circle_outline),
              label: Text(
                status == 'delivered' ? "Delivered" : "Mark as Delivered",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'delivered' ? Colors.grey : Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )

          ],
        ),
      ),
    );
  }
}
