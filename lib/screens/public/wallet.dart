import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

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
  String _name = '';
  String _lastName = '';
  String _profileImageUrl = '';
  DateTime _currentTime = DateTime.now();
  bool _isBalanceHidden = true;
  bool _isLoading = true;
  String _userDocId = ''; // Define la variable aquí

  StreamSubscription<DocumentSnapshot>? _walletSubscription;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _fetchClientId();
      _updateTime();
    });
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    super.dispose();
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

        final QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore
            .instance
            .collection('users')
            .where('uid', isEqualTo: _userId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userDoc = querySnapshot.docs.first;
          final userData = userDoc.data();
          _userDocId = userDoc.id; // Asigna el userDocId aquí

          setState(() {
            _name = userData['name'] ?? '';
            _lastName = userData['lastName'] ?? '';
            _profileImageUrl = userData['profileImageUrl'] ?? '';
          });

          // Establecer el listener para el documento del wallet
          _walletSubscription = FirebaseFirestore.instance
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

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceHidden = !_isBalanceHidden;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Monedero',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 30),
                child: Text(
                  '${DateFormat('EEEE', 'es_ES').format(_currentTime)[0].toUpperCase()}${DateFormat('EEEE', 'es_ES').format(_currentTime).substring(1)}, ${DateFormat('dd/MM/yyyy HH:mm:ss', 'es_ES').format(_currentTime)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF08143c),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundImage: _profileImageUrl.isNotEmpty
                              ? NetworkImage(_profileImageUrl)
                              : null,
                          child: _profileImageUrl.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_name $_lastName',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1ca424),
                          ),
                          child: const Center(
                            child: Text(
                              '\$',
                              style: TextStyle(color: Colors.white, fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isBalanceHidden ? '****' : (_walletBalance?.toStringAsFixed(2) ?? '0.00'),
                              style: const TextStyle(fontSize: 36, color: Colors.white),
                            ),
                        IconButton(
                          icon: Icon(_isBalanceHidden ? Icons.visibility : Icons.visibility_off, size: 25),
                          color: Colors.blueGrey[200],
                          onPressed: _toggleBalanceVisibility,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TransferFundsScreen()),
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.42,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: const Color(0xFF08143c)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.offline_share, size: 50, color: Color(0xFF08143c)),
                        SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Transferir', style: TextStyle(fontSize: 18)),
                            Text('fondos', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyCardsScreen(userId: _userDocId)), // Pasar userDocId
                    );
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.42,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: const Color(0xFF08143c)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          const Text('Mis tarjetas', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/VISA_Logo.png', height: 30),
                              const SizedBox(width: 5),
                              Image.asset('assets/images/MasterCard_Logo.png', height: 30),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.91,
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  border: Border.all(color: const Color(0xFF08143c)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial de transacciones',
                        style: TextStyle(fontSize: 20),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 30,
                        color: Color(0xFF08143c),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCardsScreen extends StatefulWidget {
  final String userId;

  const MyCardsScreen({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _MyCardsScreenState createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  String? _selectedCardNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Mis tarjetas', style: TextStyle(color: Colors.black)),
        actions: [
          if (_selectedCardNumber != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCard(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddCardScreen(userId: widget.userId)),
          );
        },
        backgroundColor: const Color(0xFF1ca424),
        label: const Text('Agregar tarjeta', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: GestureDetector(
        onTap: _deselectCard,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wallets')
              .doc(widget.userId)
              .collection('cards')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final cards = snapshot.data!.docs;
            return ListView.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                return _buildCardWidget(cards[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardWidget(DocumentSnapshot card) {
    final isSelected = card['cardNumber'] == _selectedCardNumber;
    final cardType = card['cardType'];
    final cardColor = cardType.toLowerCase() == 'visa' ? const Color.fromARGB(255, 6, 9, 69) : const Color(0xFF3F3F3F);
    const textColor = Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCardNumber = isSelected ? null : card['cardNumber'];
        });
      },
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10.0),
          border: isSelected ? Border.all(color: Colors.red, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(card['cardCategory'], style: const TextStyle(color: textColor, fontSize: 18)),
                Image.asset(
                  cardType.toLowerCase() == 'visa' ? 'assets/images/VISA_Logo.png' : 'assets/images/MasterCard_Logo.png',
                  height: 40,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(card['cardNumber'], style: const TextStyle(color: textColor, fontSize: 22, letterSpacing: 4)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TITULAR', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                    Text(card['cardholderName'], style: const TextStyle(color: textColor, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EXPIRA', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                    Text(card['expiryDate'], style: const TextStyle(color: textColor, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCard() async {
    if (_selectedCardNumber != null) {
      try {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.userId)
            .collection('cards')
            .doc(_selectedCardNumber)
            .delete();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarjeta eliminada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedCardNumber = null;
        });
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la tarjeta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deselectCard() {
    setState(() {
      _selectedCardNumber = null;
    });
  }
}

class AddCardScreen extends StatefulWidget {
  final String userId;

  const AddCardScreen({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _AddCardScreenState createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  String _cardNumber = '';
  String _cardholderName = '';
  String _expiryDate = '';
  String _cvv = '';
  String _cardType = '';
  String _cardCategory = 'Débito';
  int _expiryMonth = 1;
  int _expiryYear = DateTime.now().year;

  bool _validateCardNumber(String cardNumber) {
  // Eliminar espacios y guiones
  cardNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
  
  if (cardNumber.length < 13 || cardNumber.length > 19) return false;

  int sum = 0;
  bool alternate = false;
  for (int i = cardNumber.length - 1; i >= 0; i--) {
    int n = int.parse(cardNumber[i]);
    if (alternate) {
      n *= 2;
      if (n > 9) {
        n = (n % 10) + 1;
      }
    }
    sum += n;
    alternate = !alternate;
  }
  return (sum % 10 == 0);
}

bool _validateExpiryDate(int month, int year) {
  final now = DateTime.now();
  if (year < now.year || (year == now.year && month < now.month)) {
    return false;
  }
  return true;
}

  String? _getCardType(String number) {
    if (number.startsWith('4')) {
      return 'Visa';
    } else if (number.startsWith('5')) {
      return 'Mastercard';
    }
    return null;
  }

  Widget _buildCardTypeIcon() {
  if (_cardType == 'Visa') {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Image.asset('assets/images/VISA_Logo.png', height: 24, width: 24),
    );
  } else if (_cardType == 'Mastercard') {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Image.asset('assets/images/MasterCard_Logo.png', height: 24, width: 24),
    );
  }
  return const SizedBox.shrink();
}

  void _saveCard() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    // Validar número de tarjeta
    if (!_validateCardNumber(_cardNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Número de tarjeta inválido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar fecha de expiración
    if (!_validateExpiryDate(_expiryMonth, _expiryYear)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fecha de expiración inválida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar tarjeta'),
          content: const Text('¿Está seguro de que desea guardar esta tarjeta?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Guardar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.userId)
            .collection('cards')
            .doc(_cardNumber)
            .set({
          'cardNumber': _cardNumber,
          'cardholderName': _cardholderName,
          'expiryDate': _expiryDate,
          'cvv': _cvv,
          'cardType': _cardType,
          'cardCategory': _cardCategory,
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarjeta guardada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la tarjeta'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Agregar Tarjeta'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Número de Tarjeta',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'Ingrese el número de tarjeta',
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
                suffixIcon: _buildCardTypeIcon()
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese el número de tarjeta';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _cardType = _getCardType(value) ?? '';
                });
              },
              onSaved: (value) => _cardNumber = value!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Nombre del Titular',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'Ingrese el nombre del titular',
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese el nombre del titular';
                }
                return null;
              },
              onSaved: (value) => _cardholderName = value!,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _expiryMonth,
                    decoration: InputDecoration(
                      labelText: 'Mes de Expiración',
                      labelStyle: const TextStyle(color: Colors.black),
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
                    items: List.generate(12, (index) => index + 1).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString().padLeft(2, '0')),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _expiryMonth = newValue!;
                      });
                    },
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _expiryYear,
                    decoration: InputDecoration(
                      labelText: 'Año de Expiración',
                      labelStyle: const TextStyle(color: Colors.black),
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
                    items: List.generate(10, (index) => DateTime.now().year + index).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _expiryYear = newValue!;
                      });
                    },
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      labelStyle: const TextStyle(color: Colors.black),
                      hintText: 'Ingrese el CVV',
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el CVV';
                      }
                      if (value.length != 3) {
                        return 'El CVV debe tener 3 dígitos';
                      }
                      return null;
                    },
                    onSaved: (value) => _cvv = value!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _cardCategory,
                    decoration: InputDecoration(
                      labelText: 'Categoría de Tarjeta',
                      labelStyle: const TextStyle(color: Colors.black),
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
                    items: ['Débito', 'Crédito'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _cardCategory = newValue!;
                      });
                    },
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _expiryDate = '${_expiryMonth.toString().padLeft(2, '0')}/${_expiryYear.toString().substring(2)}';
                _saveCard();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ca424),
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransferFundsScreen extends StatelessWidget {
  const TransferFundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Transferir fondos', style: TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Text('Contenido de Transferir fondos'),
      ),
    );
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Historial de transacciones', style: TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Text('Contenido del Historial de transacciones'),
      ),
    );
  }
}