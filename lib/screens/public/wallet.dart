import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double? _walletBalance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userId = '';
  DateTime _currentTime = DateTime.now();
  bool _isLoading = true;
  String _userDocId = '';
  String _userName = '';
  String _userLastName = '';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _fetchClientId();
      _loadUserData();
      _updateTime();
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTime.now();
    });
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  Future _fetchClientId() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;

        final QuerySnapshot<Map<String, dynamic>> querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: _userId)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;
          _userDocId = userDoc.id;

          FirebaseFirestore.instance
              .collection('wallets')
              .doc(_userDocId)
              .snapshots()
              .listen((walletDoc) {
            if (walletDoc.exists) {
              setState(() {
                _walletBalance = walletDoc.data()?['walletBalance'];
                _isLoading = false;
              });
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user data: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(combinedId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userName = userDoc.data()!['name'];
          _userLastName = userDoc.data()!['lastName'];
          _profileImageUrl = userDoc.data()!['profileImageUrl'] ?? '';
        });
      }
    }
  }

  Future _getCombinedIdFromFirestore(String uid) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore
        .instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    return '';
  }

  void _navigateToTransferFundsScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => TransferFundsScreen(userId: _userDocId)),
  );
}

void _navigateToTransactionHistoryScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
        builder: (context) => const TransactionHistoryScreen()),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monedero',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_userName $_userLastName',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm:ss').format(_currentTime),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : null,
                        child: _profileImageUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.green)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Saldo Disponible',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoading ? '\$--' : '\$ ${_walletBalance?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(
                    icon: Icons.send,
                    label: 'Enviar',
                    onTap: _navigateToTransferFundsScreen,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tu actividad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToTransactionHistoryScreen,
                    child: const Text(
                      'Historial',
                      style: TextStyle(
                        color: Color(0xFF08143c),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildTransactionItem('Car loans', 'Chase', 5000),
                      _buildTransactionItem('Bank Account', 'Transfer to bank', -2980),
                      _buildTransactionItem('Grocery Store', 'Walmart', 550),
                      _buildTransactionItem('Shopping', 'Nike', 1300),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF08143c),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String subtitle, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFF08143c)),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '${amount >= 0 ? '+' : ''}\$${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amount >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class TransferFundsScreen extends StatefulWidget {
  final String userId;

  const TransferFundsScreen({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _TransferFundsScreenState createState() => _TransferFundsScreenState();
}

class _TransferFundsScreenState extends State<TransferFundsScreen> {
  String amount = '0';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void updateAmount(String value) {
    setState(() {
      if (amount == '0' && value != '.') {
        amount = value;
      } else if (value == '.' && !amount.contains('.')) {
        amount += value;
      } else if (value != '.') {
        amount += value;
      }
    });
  }

  void deleteLastDigit() {
    setState(() {
      if (amount.length > 1) {
        amount = amount.substring(0, amount.length - 1);
      } else {
        amount = '0';
      }
    });
  }

  void continueTransfer() async {
    double enteredAmount = double.parse(amount);

    if (enteredAmount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto mínimo a transferir es de USD 1.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DocumentSnapshot walletDoc =
        await _firestore.collection('wallets').doc(widget.userId).get();
    double walletBalance = walletDoc['walletBalance'];

    if (enteredAmount > walletBalance) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo insuficiente para realizar la transferencia.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (context) => UserSearch_TransferFundsScreen(
              amount: amount, userId: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Transferir fondos',
            style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Monto a transferir',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF08143c),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 70,
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: const Color(0xFF1ca424),
                  ),
                  child: const Center(
                    child: Text(
                      'USD',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(fontSize: 36, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 1; i <= 9; i++) buildButton(i.toString()),
                buildButton('.'),
                buildButton('0'),
                buildButton('⌫'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ca424),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: continueTransfer,
              child: const Text('Continuar', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildButton(String value) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.blue[50],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      onPressed: () {
        if (value == '⌫') {
          deleteLastDigit();
        } else {
          updateAmount(value);
        }
      },
      child: Text(
        value,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}

// ignore: camel_case_types
class UserSearch_TransferFundsScreen extends StatefulWidget {
  final String amount;
  final String userId;

  const UserSearch_TransferFundsScreen(
      {super.key, required this.amount, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _UserSearch_TransferFundsScreenState createState() =>
      _UserSearch_TransferFundsScreenState();
}

// ignore: camel_case_types
class _UserSearch_TransferFundsScreenState
    extends State<UserSearch_TransferFundsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    QuerySnapshot querySnapshot = await _firestore.collection('users').get();
    setState(() {
      _users = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      _filteredUsers = [];
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _filteredUsers = [];
      } else {
        _filteredUsers = _users.where((user) {
          final id = user['id'].toString().toLowerCase();
          final searchLower = value.toLowerCase();
          return id.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Seleccionar usuario',
            style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[200],
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Icon(
                    Icons.search,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Ingresar ID del usuario",
                      border: InputBorder.none,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
          if (_filteredUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Busque y seleccione al destinatario de sus fondos",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                return _buildUserTile(_filteredUsers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmTransferFundsScreen(
              userId: widget.userId,
              amount: widget.amount,
              recipient: user,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF08143C),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user['name']} ${user['lastName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('ID: ${user['id']}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmTransferFundsScreen extends StatefulWidget {
  final String amount;
  final String userId;
  final Map<String, dynamic> recipient;

  const ConfirmTransferFundsScreen({
    super.key,
    required this.amount,
    required this.recipient,
    required this.userId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _ConfirmTransferFundsScreenState createState() =>
      _ConfirmTransferFundsScreenState();
}

class _ConfirmTransferFundsScreenState
    extends State<ConfirmTransferFundsScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? _pin;
  String _userDocId = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.userId)
        .get();
    DocumentSnapshot userInfoDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    setState(() {
      _userDocId = userDoc.id;
      _pin = userDoc.get('pin');
      _userName = '${userInfoDoc.get('name')} ${userInfoDoc.get('lastName')}';
    });
  }

  void _showPinDialog() {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Por favor, ingrese un concepto para la transferencia.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_pin == null) {
      _showCreatePinDialog();
    } else {
      _showEnterPinDialog();
    }
  }

  void _showCreatePinDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newPin = '';
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Crear PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Por favor, cree un PIN de 4 dígitos para procesar el pago.'),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  labelStyle: const TextStyle(color: Colors.black),
                  hintText: 'Ingrese un PIN de 4 dígitos',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                ),
                onChanged: (value) {
                  newPin = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () {
                if (newPin.length == 4) {
                  _savePin(newPin);
                  Navigator.of(context).pop();
                  _processPayment();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('El PIN debe tener 4 dígitos')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEnterPinDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String enteredPin = '';
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ingresar PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Por favor, ingrese su PIN único de 4 dígitos para procesar la transferencia.'),
              const SizedBox(
                height: 16,
              ),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  labelStyle: const TextStyle(color: Colors.black),
                  hintText: 'Ingrese su PIN de 4 dígitos',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                ),
                onChanged: (value) {
                  enteredPin = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirmar',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              onPressed: () {
                if (enteredPin == _pin) {
                  Navigator.of(context).pop();
                  _processPayment();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN incorrecto'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _savePin(String pin) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userDocId)
          .update({'pin': pin});
      setState(() {
        _pin = pin;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving PIN: $e');
      }
    }
  }

  void _processPayment() async {
    try {
      // Obtener el monto como número
      double amount = double.parse(widget.amount);

      // Actualizar el balance del emisor
      DocumentReference senderWalletRef =
          FirebaseFirestore.instance.collection('wallets').doc(widget.userId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot senderSnapshot =
            await transaction.get(senderWalletRef);
        double currentBalance =
            (senderSnapshot.get('walletBalance') as num).toDouble();
        if (currentBalance < amount) {
          throw Exception('Saldo insuficiente');
        }
        transaction.update(
            senderWalletRef, {'walletBalance': currentBalance - amount});
      });

      // Actualizar el balance del destinatario
      DocumentReference recipientWalletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.recipient['id']);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot recipientSnapshot =
            await transaction.get(recipientWalletRef);
        double currentBalance =
            (recipientSnapshot.get('walletBalance') as num).toDouble();
        transaction.update(
            recipientWalletRef, {'walletBalance': currentBalance + amount});
      });

      // Registrar la transacción
      DocumentReference transactionRef =
          await FirebaseFirestore.instance.collection('transactions').add({
        'date': Timestamp.now(),
        'amount': amount,
        'concept': _commentController.text,
        'senderId': widget.userId,
        'senderName': _userName,
        'recipientId': widget.recipient['id'],
        'recipientName':
            '${widget.recipient['name']} ${widget.recipient['lastName']}',
        'paymentType': 'Transferencia de fondos',
      });

      // Navegar a la pantalla de recibo
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TransactionReceiptScreen(
            paymentType: 'Transferencia de fondos',
            date: DateTime.now(),
            transactionId: transactionRef.id,
            concept: _commentController.text,
            recipientId: widget.recipient['id'],
            recipientName:
                '${widget.recipient['name']} ${widget.recipient['lastName']}',
            amount: amount,
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error procesando el pago: $e');
      }
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar transferencia'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.swap_horizontal_circle_rounded,
                  size: 60,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08143c),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: const Color(0xFF1ca424),
                        ),
                        child: const Center(
                          child: Text(
                            'USD',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.amount,
                        style:
                            const TextStyle(fontSize: 36, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Destinatario',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.recipient['name']} ${widget.recipient['lastName']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 0),
                Text(
                  '${widget.recipient['id']}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF08143c),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    labelStyle: const TextStyle(color: Colors.black),
                    hintText: 'Ingrese un concepto o comentario',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1ca424),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _showPinDialog,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 8),
                        Text('Transferir fondos',
                            style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionReceiptScreen extends StatelessWidget {
  final String paymentType;
  final DateTime date;
  final String transactionId;
  final String concept;
  final String recipientId;
  final String recipientName;
  final double amount;
  final VoidCallback? onBackPressed;

  TransactionReceiptScreen({
    super.key,
    required this.paymentType,
    required this.date,
    required this.transactionId,
    required this.concept,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    this.onBackPressed,
  });

  final ScreenshotController screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (onBackPressed != null) {
          onBackPressed!();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const HomePage(selectedIndex: 3)),
            (Route<dynamic> route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Detalle de Transacción'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (context) => const HomePage(selectedIndex: 3)),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Screenshot(
                controller: screenshotController,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Mobile Services App',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.green,
                                size: 80,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                '¡Transacción aprobada!',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildInfoCard(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share,
                          color: Color(0xFF1CA424)), // Color del icono
                      label: const Text('Compartir',
                          style: TextStyle(
                              color: Colors.white)), // Color del texto
                      onPressed: () => _shareScreenshot(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF08143C), // Fondo del botón
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download,
                          color: Color(0xFF1CA424)), // Color del icono
                      label: const Text('Descargar',
                          style: TextStyle(
                              color: Colors.white)), // Color del texto
                      onPressed: () => _saveScreenshot(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF08143C), // Fondo del botón
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16), // Establece el radio de los bordes aquí
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey[50], // Establece el color de fondo aquí
          borderRadius: BorderRadius.circular(
              16), // Asegúrate de que coincida con el radio de la tarjeta
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  paymentType,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(context, 'Fecha',
                  DateFormat('dd/MM/yyyy HH:mm').format(date)),
              _buildInfoRow(context, 'Referencia', transactionId,
                  isCopiable: true),
              _buildInfoRow(context, 'Concepto', concept),
              _buildInfoRow(context, 'Destinatario ID ', recipientId),
              _buildInfoRow(context, 'Destinatario', recipientName),
              _buildInfoRow(
                  context, 'Monto', '\$ ${amount.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value,
      {bool isCopiable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(value),
              if (isCopiable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Referencia copiada al portapapeles')),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareScreenshot(BuildContext context) async {
    final Uint8List? image = await screenshotController.capture();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/comprobante_transaccion.png').create();
      await imagePath.writeAsBytes(image);

      final xFile = XFile(imagePath.path);
      await Share.shareXFiles([xFile], text: 'Comprobante de transacción');
    }
  }

  Future<void> _saveScreenshot(BuildContext context) async {
    try {
      final Uint8List? image = await screenshotController.capture();
      if (image != null) {
        final directory = await getExternalStorageDirectory();
        final imagePath = await File(
                '${directory!.path}/comprobante_transaccion_${DateTime.now().millisecondsSinceEpoch}.png')
            .create();
        await imagePath.writeAsBytes(image);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imagen guardada en ${imagePath.path}')),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la imagen: $e')),
      );
    }
  }
}

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Historial de transacciones',
            style: TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Text('Contenido del Historial de transacciones'),
      ),
    );
  }
}
