import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_page.dart';
import 'HomePage.dart';
import 'RenterNotificationsPage.dart';
import 'RenterReportPage.dart';



/// ------------------- Model -------------------
class RentedCloth {
  final String id;
  final String name;
  final String imageBase64;
  final String size;
  final double price;
  final String userId;
  final int quantity;
  final String? occasion;


  RentedCloth({
    required this.id,
    required this.name,
    required this.imageBase64,
    required this.size,
    required this.price,
    required this.userId,
    required this.quantity,
    this.occasion,

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
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadClothesFromFirebase();
    _loadNotificationCount();
  }

  void _loadNotificationCount() {
    final user = _auth.currentUser;
    if (user == null) return;

    DatabaseReference notifRef =
    FirebaseDatabase.instance.ref('notifications/${user.uid}');
    notifRef.onValue.listen((event) {
      final data = event.snapshot.value;
      int count = 0;
      if (data != null && data is Map<dynamic, dynamic>) {
        data.forEach((key, value) {
          final notification = Map<dynamic, dynamic>.from(value);
          if (notification['status'] == 'pending') {
            count++;
          }
        });
      }
      setState(() {
        _notificationCount = count;
      });
    });
  }

  void _loadClothesFromFirebase() {
    final user = _auth.currentUser;
    if (user == null) return;

    DatabaseReference ref = FirebaseDatabase.instance.ref('rented_clothes');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      final List<RentedCloth> loadedClothes = [];
      if (data != null && data is Map<dynamic, dynamic>) {
        data.forEach((key, value) {
          final cloth = Map<String, dynamic>.from(value);
          if (cloth['userId'] == user.uid) {
            loadedClothes.add(RentedCloth(
              id: cloth['id'] ?? key,
              name: cloth['name'] ?? '',
              size: cloth['size'] ?? '',
              price: double.tryParse(cloth['price'].toString()) ?? 0,
              imageBase64: cloth['imageBase64'] ?? '',
              userId: cloth['userId'] ?? '',
              quantity: int.tryParse(cloth['quantity']?.toString() ?? '0') ?? 0,
              occasion: cloth['occasion'],
            ));
          }
        });
      }
      setState(() => _rentedClothes = loadedClothes);
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
        title: Text(
          'My Rented Clothes',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RenterNotificationsPage(
                        renterId: _auth.currentUser!.uid,
                      ),
                    ),
                  );
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: isDark ? Colors.grey[850] : Colors.white,
            child: ListTile(
              leading: Image.memory(
                base64Decode(cloth.imageBase64),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
              title: Text(
                cloth.name,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              subtitle: Text(
                'Size: ${cloth.size} | Price: ${cloth.price} | Qty: ${cloth.quantity}',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _navigateToUpdateScreen(cloth),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCloth(cloth.id),
                  ),
                ],
              ),
            ),
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
        currentIndex: 0, // start with Reports selected
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RenterReportPage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),

    );
  }
}


/// ------------------- Add Clothes Screen -------------------
class AddClothesDetailsScreen extends StatefulWidget {
  const AddClothesDetailsScreen({super.key});

  @override
  State<AddClothesDetailsScreen> createState() =>
      _AddClothesDetailsScreenState();
}

class _AddClothesDetailsScreenState extends State<AddClothesDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  File? _pickedImage;
  bool _imageError = false;
  final _auth = FirebaseAuth.instance;
  String? selectedSize;
  final List<String> sizes = ['X-Small','Small','Medium','Large','X-Large','XX-Large'];
  String? selectedOccasion;
  final List<String> occasions = ['Eid Al-Fitr', 'National Day','Eid Al-Adha'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _imageError = false;
      });
    }
  }

  void _saveCloth() async {
    if (!_formKey.currentState!.validate() || _pickedImage == null) {
      setState(() => _imageError = _pickedImage == null);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final bytes = await _pickedImage!.readAsBytes();
    final base64Image = base64Encode(bytes);

    final newCloth = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': nameController.text.trim(),
      'size': selectedSize,
      'price': double.parse(priceController.text),
      'imageBase64': base64Image,
      'userId': user.uid,
      'quantity': int.parse(quantityController.text),
      'available': int.parse(quantityController.text) > 0,
      'occasion': selectedOccasion,
    };

    await FirebaseDatabase.instance
        .ref('rented_clothes/${newCloth['id']}')
        .set(newCloth);

    Navigator.pop(context);
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      validator: (value) {
        // Check if field is empty
        if (value == null || value.trim().isEmpty) {
          return '$label cannot be empty';
        }

        // Name validation: allow letters and spaces only
        if (label == "Name of the cloth") {
          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
            return 'Name must contain only letters';
          }
        }

        // Price validation: must be a number greater than 0
        if (label == "Price") {
          final price = double.tryParse(value);
          if (price == null || price <= 0) {
            return 'Price must be greater than 0';
          }
        }

        // Quantity validation: must be a whole number greater than 0
        if (label == "Quantity") {
          final quantity = int.tryParse(value);
          if (quantity == null || quantity <= 0) {
            return 'Quantity must be greater than 0';
          }
        }

        return null;
      },

      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor),
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 28, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Center(
                    child: Text('Add New Cloth',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor))),
                const SizedBox(height: 32),
                _buildTextField("Name of the cloth", nameController),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSize,
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  decoration: InputDecoration(
                    labelText: "Size",
                    filled: true,
                    fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: sizes.map((size) => DropdownMenuItem(
                    value: size,
                    child: Text(size, style: TextStyle(color: textColor)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedSize = value),
                  validator: (value) => value == null ? "Please select a size" : null,
                ),
                const SizedBox(height: 16),
                _buildTextField("Price", priceController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildTextField("Quantity", quantityController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedOccasion,
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  decoration: InputDecoration(
                    labelText: "Occasion",
                    filled: true,
                    fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: occasions.map((occ) => DropdownMenuItem(
                    value: occ,
                    child: Text(occ, style: TextStyle(color: textColor)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedOccasion = value),
                  validator: (value) => value == null ? 'Please select an occasion' : null,
                ),

                const SizedBox(height: 16),
                Text("Pick Image", style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                        color: inputColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey)),
                    child: _pickedImage != null
                        ? Image.file(_pickedImage!, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
                  ),
                ),
                if (_imageError) const SizedBox(height: 8),
                if (_imageError)
                  const Text("Please pick an image", style: TextStyle(color: Colors.red, fontSize: 14)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveCloth,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("Add Cloth", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------- Update Clothes Screen -------------------
class UpdateClothScreen extends StatefulWidget {
  final RentedCloth cloth;
  const UpdateClothScreen({super.key, required this.cloth});

  @override
  State<UpdateClothScreen> createState() => _UpdateClothScreenState();
}

class _UpdateClothScreenState extends State<UpdateClothScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  String? selectedSize;
  final List<String> sizes = ['X-Small','Small','Medium','Large','X-Large','XX-Large'];
  late TextEditingController priceController;
  late TextEditingController quantityController;
  File? _pickedImage;

  // --------------------- Occasion ---------------------
  String? selectedOccasion;
  final List<String> occasions = ['Eid Al-Fitr', 'National Day','Eid Al-Adha'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.cloth.name);
    selectedSize = widget.cloth.size;
    priceController = TextEditingController(text: widget.cloth.price.toString());
    quantityController = TextEditingController(text: widget.cloth.quantity.toString());
    selectedOccasion = widget.cloth.occasion;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    String base64Image = widget.cloth.imageBase64;
    if (_pickedImage != null) {
      final bytes = await _pickedImage!.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    final updatedCloth = {
      'id': widget.cloth.id,
      'name': nameController.text.trim(),
      'size': selectedSize,
      'price': double.parse(priceController.text),
      'imageBase64': base64Image,
      'userId': widget.cloth.userId,
      'quantity': int.parse(quantityController.text),
      'occasion': selectedOccasion,
    };

    await FirebaseDatabase.instance
        .ref('rented_clothes/${widget.cloth.id}')
        .update(updatedCloth);
    Navigator.pop(context);
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor),
      validator: (value) {
        // Check if the field is empty
        if (value == null || value.trim().isEmpty) {
          return '$label cannot be empty';
        }

        // Name validation: allow letters and spaces only
        if (label == "Name of the cloth") {
          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
            return 'Name must contain only letters';
          }
        }

        // Price validation: must be a number greater than 0
        if (label == "Price") {
          final price = double.tryParse(value);
          if (price == null || price <= 0) {
            return 'Price must be greater than 0';
          }
        }

        // Quantity validation: must be a whole number greater than 0
        if (label == "Quantity") {
          final quantity = int.tryParse(value);
          if (quantity == null || quantity <= 0) {
            return 'Quantity must be greater than 0';
          }
        }

        return null;
      },

      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor),
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 28, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Center(
                    child: Text('Update Cloth',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor))),
                const SizedBox(height: 32),
                _buildTextField("Name of the cloth", nameController),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSize,
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  decoration: InputDecoration(
                    labelText: "Size",
                    filled: true,
                    fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: sizes.map((size) => DropdownMenuItem(
                    value: size,
                    child: Text(size, style: TextStyle(color: textColor)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedSize = value),
                  validator: (value) => value == null ? "Please select a size" : null,
                ),
                const SizedBox(height: 16),
                _buildTextField("Price", priceController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildTextField("Quantity", quantityController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),

                // ------------------- Occasion Dropdown -------------------
                DropdownButtonFormField<String>(
                  value: selectedOccasion,
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  decoration: InputDecoration(
                    labelText: "Occasion",
                    filled: true,
                    fillColor: inputColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: occasions.map((occ) => DropdownMenuItem(
                    value: occ,
                    child: Text(occ, style: TextStyle(color: textColor)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedOccasion = value),
                  validator: (value) => value == null ? 'Please select an occasion' : null,
                ),
                const SizedBox(height: 16),

                Text("Pick Image", style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                        color: inputColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey)),
                    child: _pickedImage != null
                        ? Image.file(_pickedImage!, fit: BoxFit.cover)
                        : Image.memory(base64Decode(widget.cloth.imageBase64), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("Update Cloth", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

