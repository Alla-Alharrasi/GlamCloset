import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_page.dart';
import 'AccountDetails.dart';

/// ------------------- Model -------------------
class RentedCloth {
  final String id;
  final String name;
  final String imageBase64;
  final String ageRange;
  final double price;
  final String userId;
  final int quantity; 

  RentedCloth({
    required this.id,
    required this.name,
    required this.imageBase64,
    required this.ageRange,
    required this.price,
    required this.userId,
    required this.quantity, 
  });
}

/// ------------------- Rented Clothes Screen -------------------
class RentedClothesScreen extends StatefulWidget {
  const RentedClothesScreen({super.key});

  @override
  State<RentedClothesScreen> createState() => _RentedClothesScreenState();
}

class _RentedClothesScreenState extends State<RentedClothesScreen> {
  List<RentedCloth> _rentedClothes = [];
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadClothesFromFirebase();
  }

  void _loadClothesFromFirebase() {
    final user = _auth.currentUser;
    if (user == null) return;

    DatabaseReference ref = FirebaseDatabase.instance.ref('rented_clothes');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        final List<RentedCloth> loadedClothes = [];
        data.forEach((key, value) {
          if (value is Map && value['userId'] == user.uid) {
            loadedClothes.add(RentedCloth(
              id: value['id'] ?? key,
              name: value['name'] ?? '',
              ageRange: value['ageRange'] ?? '',
              price: double.tryParse(value['price'].toString()) ?? 0,
              imageBase64: value['imageBase64'] ?? '',
              userId: value['userId'] ?? '',
              quantity: int.tryParse(value['quantity']?.toString() ?? '0') ?? 0, 
            ));
          }
        });
        setState(() {
          _rentedClothes = loadedClothes;
        });
      } else {
        setState(() => _rentedClothes = []);
      }
    });
  }

  void _deleteCloth(String id) async {
    await FirebaseDatabase.instance.ref('rented_clothes/$id').remove();
  }

  void _navigateToAddScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddClothesDetailsScreen()),
    ).then((_) => _loadClothesFromFirebase());
  }

  void _navigateToUpdateScreen(RentedCloth cloth) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UpdateClothScreen(cloth: cloth)),
    ).then((_) => _loadClothesFromFirebase());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Rented Clothes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _rentedClothes.isEmpty
          ? Center(
              child: Text(
                'No clothes yet. Click + to add.',
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _rentedClothes.length,
              itemBuilder: (context, index) {
                final cloth = _rentedClothes[index];
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [Colors.indigo[700]!, Colors.grey]
                              : [Colors.deepPurpleAccent, Colors.pinkAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black54 : Colors.black26,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: cloth.imageBase64.isNotEmpty
                              ? MemoryImage(base64Decode(cloth.imageBase64))
                              : null,
                          child: cloth.imageBase64.isEmpty
                              ? const Icon(Icons.image,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          cloth.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white),
                        ),
                        subtitle: Text(
                          'Age: ${cloth.ageRange}\nQuantity: ${cloth.quantity}', 
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 28),
                              onPressed: () => _navigateToUpdateScreen(cloth),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.white, size: 28),
                              onPressed: () => _deleteCloth(cloth.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20),
                            bottomLeft: Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${cloth.price} OMR',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddScreen,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: isDark ? Colors.white70 : Colors.grey,
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => AccountDetailsPage()));
          } else if (index == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => SettingsPage()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
