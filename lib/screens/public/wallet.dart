import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _transactions = [];

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
              .collection('users')
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

          _fetchTransactions();
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

  Future<void> _fetchTransactions() async {
    final query = FirebaseFirestore.instance
        .collection('transactions')
        .where(Filter.or(
          Filter('recipientId', isEqualTo: _userDocId),
          Filter('senderId', isEqualTo: _userDocId),
        ))
        .orderBy('date', descending: true)
        .limit(5);

    query.snapshots().listen((snapshot) {
      setState(() {
        _transactions = snapshot.docs
            .where((doc) =>
                doc['recipientId'] == _userDocId ||
                doc['senderId'] == _userDocId)
            .toList();
      });
    });
  }

  Future<void> _loadUserData() async {
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

  Future<String> _getCombinedIdFromFirestore(String uid) async {
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

  void _navigateToTransferFundsScreen() async {
    // Obtener el rol del usuario actual
    final User? user = _auth.currentUser;
    if (user != null) {
      final combinedId = await _getCombinedIdFromFirestore(user.uid);
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(combinedId).get();
      final userRole = userDoc.data()?['role'];

      // Validar el rol
      if (userRole == 1) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Restringido para agentes activos.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
              builder: (context) => TransferFundsScreen(userId: _userDocId)),
        );
      }
    }
  }

  void _navigateToTransactionHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
    );
  }

  void _navigateToTransactionReceiptScreen(
      QueryDocumentSnapshot<Map<String, dynamic>> transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionReceiptScreen2(
          paymentType: transaction.data()['paymentType'] ?? 'Desconocido',
          date: (transaction.data()['date'] as Timestamp).toDate(),
          transactionId: transaction.id, // Usar el ID del documento aquí
          concept: transaction.data()['concept'] ?? '',
          recipientId: transaction.data()['recipientId'] ?? '',
          recipientName: transaction.data()['recipientName'] ?? '',
          amount: transaction.data()['amount'].toDouble(),
          paymentMethod: transaction.data()['paymentMethod'] ?? {},
          taskId: transaction.data()['taskId'] ?? '',
          senderName: transaction.data()['senderName'] ?? '',
          senderId: transaction.data()['senderId'] ?? '',
        ),
      ),
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
                            DateFormat('dd/MM/yyyy HH:mm:ss')
                                .format(_currentTime),
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
                            : const AssetImage(
                                    'assets/images/ProfilePhoto_predetermined.png')
                                as ImageProvider,
                      ).animate().fade().scale(),
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
                _isLoading
                    ? '\$--'
                    : '\$ ${_walletBalance?.toStringAsFixed(2) ?? '0.00'}',
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
                    'Actividad reciente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToTransactionHistoryScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                            color: const Color(0xFF08143c), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Historial',
                        style: TextStyle(
                          color: Color(0xFF08143c),
                          fontWeight: FontWeight.bold,
                        ),
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index].data();
                      final isSentByUser =
                          transaction['senderId'] == _userDocId;
                      final icon = isSentByUser
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded;
                      final name = isSentByUser
                          ? transaction['recipientName']
                          : transaction['senderName'];
                      final amount = transaction['amount'];
                      final amountDouble = (amount is int)
                          ? amount.toDouble()
                          : (amount as double);
                      final paymentType = transaction['paymentType'];

                      return GestureDetector(
                        onTap: () => _navigateToTransactionReceiptScreen(
                            _transactions[index]),
                        child: _buildTransactionItem(name, paymentType,
                            amountDouble, icon, isSentByUser),
                      );
                    },
                  ),
                ),
              )
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

  Widget _buildTransactionItem(String title, String subtitle, double amount,
      IconData icon, bool isSentByUser) {
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
                child: Icon(
                  icon,
                  size: 40,
                  color: const Color(0xFF08143c),
                ),
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
            '${isSentByUser ? '-' : '+'}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSentByUser ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _userId = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _transactions = [];
  String _selectedFilter = 'Todas';
  int _transactionLimit = 15;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _isLoading = true;
  Timer? _debounce;
  DateTime? _startDate;
  DateTime? _endDate;
  int _totalTransactions = 0;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _getUserId();
    });
  }

  Future<void> _getUserId() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _userId = querySnapshot.docs.first.id;
        });
        _fetchTransactions();
      }
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
    });

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('date', descending: true);

    query = query.where(Filter.or(
      Filter('senderId', isEqualTo: _userId),
      Filter('recipientId', isEqualTo: _userId),
    ));

    if (_selectedFilter == 'Enviadas') {
      query = query.where('senderId', isEqualTo: _userId);
    } else if (_selectedFilter == 'Recibidas') {
      query = query.where('recipientId', isEqualTo: _userId);
    }

    if (_startDate != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
    }
    if (_endDate != null) {
      query = query.where('date',
          isLessThanOrEqualTo:
              Timestamp.fromDate(_endDate!.add(const Duration(days: 1))));
    }

    // Obtener el total de transacciones
    final totalSnapshot = await query.count().get();
    _totalTransactions = totalSnapshot.count!;

    // Aplicar paginación
    query = query.limit(_transactionLimit);
    if (_currentPage > 1 && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    if (_searchQuery.isNotEmpty) {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          filteredTransactions = [];
      for (var doc in snapshot.docs) {
        final senderId = doc['senderId'];
        final recipientId = doc['recipientId'];
        final transactionId = doc.id;

        final senderName = await _getUserName(senderId);
        final recipientName = await _getUserName(recipientId);

        if (senderName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            recipientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            senderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            recipientId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            transactionId.toLowerCase().contains(_searchQuery.toLowerCase())) {
          filteredTransactions.add(doc);
        }
      }

      setState(() {
        _transactions = filteredTransactions;
        _isLoading = false;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      });
    } else {
      setState(() {
        _transactions = snapshot.docs;
        _isLoading = false;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      });
    }
  }

  Future<void> _showDateRangePicker() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('es', ''),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF08143c),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF08143c),
              onPrimary: Colors.white,
              secondary: Color(0xFFE3F2FD),
            ),
            dialogBackgroundColor: Colors.white,
            scaffoldBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                foregroundColor: Colors.white,
              ),
            ),
            textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: const Color(0xFF08143c),
                  displayColor: const Color(0xFF08143c),
                ),
          ),
          child: child!,
        );
      },
      cancelText: 'Cancelar',
      confirmText: 'Buscar',
      saveText: 'Buscar',
      helpText: 'Seleccionar rango',
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
      _fetchTransactions();
    }
  }

  Future<String> _getUserName(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return '${userDoc.data()!['name']} ${userDoc.data()!['lastName']}';
    } else {
      return 'Usuario desconocido';
    }
  }

  void _navigateToTransactionReceiptScreen(
      QueryDocumentSnapshot<Map<String, dynamic>> transactionDoc) {
    final transaction = transactionDoc.data();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionReceiptScreen2(
          paymentType: transaction['paymentType'] ?? 'Desconocido',
          date: (transaction['date'] as Timestamp).toDate(),
          transactionId: transactionDoc.id, // Usar el ID del documento aquí
          concept: transaction['concept'] ?? '',
          recipientId: transaction['recipientId'] ?? '',
          recipientName: transaction['recipientName'] ?? '',
          amount: transaction['amount'].toDouble(),
          paymentMethod: transaction['paymentMethod'] ?? {},
          taskId: transaction['taskId'] ?? '',
          senderName: transaction['senderName'] ?? '',
          senderId: transaction['senderId'] ?? '',
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      QueryDocumentSnapshot<Map<String, dynamic>> transaction) {
    final data = transaction.data();
    final bool isIncome = data['recipientId'] == _userId;
    final String amount = '\$${data['amount'].toStringAsFixed(2)}';
    final String description = data['concept'] ?? 'Sin descripción';
    // ignore: unused_local_variable
    final DateTime date = (data['date'] as Timestamp).toDate();

    Future<String> nameFuture =
        _getUserName(isIncome ? data['senderId'] : data['recipientId']);

    return FutureBuilder<String>(
      future: nameFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final name = snapshot.data!;
          final paymentType = data['paymentType'] ?? 'Sin tipo';
          final icon = isIncome
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded;

          return GestureDetector(
            onTap: () => _navigateToTransactionReceiptScreen(transaction),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.grey,
                        width: 0.7,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: const Color(0xFF08143c),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          paymentType,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          description,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isIncome ? '+$amount' : '-$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return const Center(
              child: CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          ));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Center(
          child: Text(
            'Historial de transacciones',
            style: TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.black),
            onPressed: _showDateRangePicker,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF08143c),
                        width: 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF08143c),
                        width: 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF08143c),
                        width: 1.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      setState(() {
                        _searchQuery = value;
                      });
                      _fetchTransactions();
                    });
                  },
                ),
                const SizedBox(height: 8.0),
                const Center(
                  child: Text(
                    'Ingrese el ID del usuario, el nombre o la referencia de la transacción.',
                    style: TextStyle(
                      fontSize: 10.0,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildFilterButton('Todas'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Enviadas'),
                      const SizedBox(width: 8),
                      _buildFilterButton('Recibidas'),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 74.3),
                  child: DropdownButtonFormField<int>(
                    value: _transactionLimit,
                    isDense: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 4.0,
                      ),
                    ),
                    items: [5, 15, 30, 50, 100].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: Text(value.toString()),
                        ),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _transactionLimit = newValue;
                        });
                        _fetchTransactions();
                      }
                    },
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                )
              ],
            ),
          ),
          _buildDateRangeIndicator(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tu actividad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(
                    radius: 25,
                    color: Colors.green,
                  ))
                : _transactions.isEmpty
                    ? Center(
                        child: Text(
                          _getNoTransactionsMessage(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          final date =
                              (transaction['date'] as Timestamp).toDate();

                          if (index == 0 ||
                              !_isSameDay(
                                  date,
                                  ((_transactions[index - 1]['date']
                                          as Timestamp)
                                      .toDate()))) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    _getDateHeader(date),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildTransactionItem(transaction),
                              ],
                            );
                          }
                          return _buildTransactionItem(transaction);
                        },
                      ),
          ),
          if (!_isLoading && _transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() {
                              _currentPage--;
                              _lastDocument =
                                  null; // Resetear el último documento
                            });
                            _fetchTransactions();
                          }
                        : null,
                  ),
                  Text(
                      'Página $_currentPage de ${(_totalTransactions / _transactionLimit).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage <
                            (_totalTransactions / _transactionLimit).ceil()
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                            _fetchTransactions();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeIndicator() {
    if (_startDate == null || _endDate == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 0.0),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'Desde ${DateFormat('dd/MM/yyyy').format(_startDate!)} - Hasta ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              _fetchTransactions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor:
            _selectedFilter == label ? Colors.white : const Color(0xFF08143c),
        backgroundColor: _selectedFilter == label
            ? const Color(0xFF08143c)
            : Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12.0),
      ),
      onPressed: () {
        setState(() {
          _selectedFilter = label;
        });
        _fetchTransactions();
      },
      child: Text(label),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Hoy';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    } else {
      return DateFormat('EEEE, d MMMM', 'es_ES').format(date);
    }
  }

  String _getNoTransactionsMessage() {
    switch (_selectedFilter) {
      case 'Enviadas':
        return 'No hay transacciones enviadas';
      case 'Recibidas':
        return 'No hay transacciones recibidas';
      default:
        return 'No hay transacciones';
    }
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
        SnackBar(
          content: const Text(
            'El monto mínimo a transferir es de USD 1.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    DocumentSnapshot walletDoc =
        await _firestore.collection('users').doc(widget.userId).get();
    double walletBalance = walletDoc['walletBalance'];

    if (enteredAmount > walletBalance) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Saldo insuficiente para realizar la transferencia.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where('role', isNotEqualTo: 1) // Filtra por usuarios con role != 1
        .get();
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
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
                // Verifica si el usuario tiene rol != 1 antes de mostrarlo
                if (_filteredUsers[index]['role'] != 1) {
                  return _buildUserTile(_filteredUsers[index]);
                } else {
                  return const SizedBox.shrink(); // Oculta el usuario si tiene rol 1
                }
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
    try {
      // Obtener información del usuario
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      setState(() {
        _userDocId = widget.userId;
        _pin = userDoc.get('pin') as String?;
        _userName = '${userDoc.get('name')} ${userDoc.get('lastName')}';
      });

      if (kDebugMode) {
        print('User info fetched: PIN: $_pin, Name: $_userName');
      } // Para depuración
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user info: $e');
      } // Para depuración
      // Manejar el error, tal vez mostrar un SnackBar al usuario
    }
  }

  void _showPinDialog() {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Por favor, ingrese un concepto de transferencia.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
                    SnackBar(
                      content: const Text(
                        'El PIN debe tener 4 dígitos.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                    SnackBar(
                      content: const Text(
                        'PIN incorrecto.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
      // Verificar si tenemos la información del usuario
      if (_userName.isEmpty) {
        await _fetchUserInfo(); // Intentar obtener la información de nuevo si no la tenemos
      }

      // Obtener el monto como número
      double amount = double.parse(widget.amount);

      // Actualizar el balance del emisor
      DocumentReference senderWalletRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
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
          .collection('users')
          .doc(widget.recipient['id']);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot recipientSnapshot =
            await transaction.get(recipientWalletRef);
        double currentBalance =
            (recipientSnapshot.get('walletBalance') as num).toDouble();
        transaction.update(
            recipientWalletRef, {'walletBalance': currentBalance + amount});
      });

      // Obtener la información más reciente del usuario emisor
      DocumentSnapshot senderInfoDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      String senderName =
          '${senderInfoDoc.get('name')} ${senderInfoDoc.get('lastName')}';

      // Registrar la transacción
      DocumentReference transactionRef =
          await FirebaseFirestore.instance.collection('transactions').add({
        'date': Timestamp.now(),
        'amount': amount,
        'concept': _commentController.text,
        'senderId': widget.userId,
        'senderName': senderName, // Usar el nombre obtenido justo ahora
        'recipientId': widget.recipient['id'],
        'recipientName':
            '${widget.recipient['name']} ${widget.recipient['lastName']}',
        'paymentType': 'Transferencia de fondos',
      });

      if (kDebugMode) {
        print('Transaction registered with sender name: $_userName');
      } // Para depuración

      // Navegar a la pantalla de recibo
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TransactionReceiptScreen2(
            paymentType: 'Transferencia de fondos',
            date: DateTime.now(),
            transactionId: transactionRef.id,
            concept: _commentController.text,
            recipientId: widget.recipient['id'],
            recipientName:
                '${widget.recipient['name']} ${widget.recipient['lastName']}',
            amount: amount,
            paymentMethod: const {},
            taskId: '',
            senderName: _userName,
            senderId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error procesando el pago: $e');
      }
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Transacción fallida.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
                      SnackBar(
                        content: const Text(
                          '¡Referencia copiada al portapapeles con éxito!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
          SnackBar(
            content: Text('Imagen guardada en ${imagePath.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la imagen: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

class TransactionReceiptScreen2 extends StatelessWidget {
  final String paymentType;
  final DateTime date;
  final String transactionId;
  final String concept;
  final String recipientId;
  final String recipientName;
  final double amount;
  final Map<String, dynamic> paymentMethod;
  final String taskId;
  final String senderName;
  final String senderId;
  final VoidCallback? onBackPressed;

  TransactionReceiptScreen2({
    super.key,
    required this.paymentType,
    required this.date,
    required this.transactionId,
    required this.concept,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    required this.paymentMethod,
    required this.taskId,
    required this.senderName,
    required this.senderId,
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
          elevation: 0,
          title: const Text('Detalle de Transacción',
              style: TextStyle(color: Colors.black)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          // Center the content
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              children: [
                Screenshot(
                  controller: screenshotController,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Centra los elementos del encabezado
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildTransactionStatus(),
                        const SizedBox(height: 24),
                        _buildInfoCard(context),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Compartir',
                        onPressed: () => _shareScreenshot(context),
                      ),
                      _buildActionButton(
                        icon: Icons.download,
                        label: 'Descargar',
                        onPressed: () => _saveScreenshot(context),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Centra el encabezado horizontalmente
      children: [
        const Text(
          'Mobile Services App',
          textAlign: TextAlign.center, // Centra el texto
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08143c)),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('dd/MM/yyyy HH:mm').format(date),
          textAlign: TextAlign.center, // Centra el texto
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTransactionStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment
          .center, // Centra los elementos de la sección de estado
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: Colors.green,
          size: 80,
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Transacción aprobada!',
          textAlign: TextAlign.center, // Centra el texto
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08143c)),
        ),
        const SizedBox(height: 8),
        Text(
          'Monto total: \$${amount.toStringAsFixed(2)}',
          textAlign: TextAlign.center, // Centra el texto
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Tipo de pago', paymentType, context: context),
            _buildInfoRow('Referencia', transactionId,
                context: context, isCopiable: true),
            _buildInfoRow('Concepto', concept, context: context),
            _buildInfoRow('Emisor', '$senderName ($senderId)',
                context: context),
            _buildInfoRow('Receptor', '$recipientName ($recipientId)',
                context: context),
            _buildPaymentMethodsSection(),
            if (taskId.isNotEmpty) _buildTaskIdSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {required BuildContext context, bool isCopiable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF08143c))),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.black87)),
              if (isCopiable)
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 20, color: Color(0xFF08143c)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    _showCopiedSnackbar(
                        context); // Pass the context to the function
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCopiedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '¡Copiado al portapeles con éxito!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    if (paymentMethod.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Métodos de pago',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF08143c))),
          ),
          ...paymentMethod.entries.map((entry) {
            final methodName = entry.key;
            final methodDetails = entry.value as Map<String, dynamic>;
            final methodAmount = methodDetails['amount'] as num;
            return Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(methodName,
                      style: const TextStyle(color: Colors.black87)),
                  Text('\$${methodAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black87)),
                ],
              ),
            );
            // ignore: unnecessary_to_list_in_spreads
          }).toList(),
        ],
      );
    } else {
      return const SizedBox
          .shrink(); // No mostrar nada si paymentMethod es nulo o vacío
    }
  }

  Widget _buildTaskIdSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Task ID',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF08143c))),
          Row(
            children: [
              Text(taskId, style: const TextStyle(color: Colors.black87)),
              IconButton(
                icon:
                    const Icon(Icons.copy, size: 20, color: Color(0xFF08143c)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: taskId));
                  // Mostrar un SnackBar o alguna notificación de que se ha copiado
                  _showCopiedSnackbar(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF08143c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          '${directory!.path}/comprobante_transaccion_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
        await imagePath.writeAsBytes(image);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagen guardada en ${imagePath.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la imagen: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
