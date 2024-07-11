import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final double _walletBalance = 0.00;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userId = '';
  String _name = '';
  String _lastName = '';
  String _profileImageUrl = '';
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null).then((_) {
      _fetchClientId();
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
          final userData = querySnapshot.docs.first.data();
          setState(() {
            _name = userData['name'] ?? '';
            _lastName = userData['lastName'] ?? '';
            _profileImageUrl = userData['profileImageUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
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
      body: Center( // Centrar todo el contenido verticalmente
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 30),
                child: Text(
                  '${DateFormat('EEEE', 'es_ES').format(_currentTime)[0].toUpperCase()}${DateFormat('EEEE', 'es_ES').format(_currentTime).substring(1)}, ${DateFormat('dd/MM/yyyy HH:mm:ss', 'es_ES').format(_currentTime)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13), // Tamaño de letra reducido
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
                        Text(
                          _walletBalance.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 36, color: Colors.white),
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
                Container(
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
                      // Icono de subir
                      Icon(Icons.offline_share, size: 50, color: Color(0xFF08143c)),
                      SizedBox(width: 8), // Espacio entre el icono y el texto
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Centra el texto verticalmente
                        children: [
                          Text('Transferir', style: TextStyle(fontSize: 18)),
                          Text('fondos', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ],
                    ),
                  ),
                ),
              const SizedBox(width: 10),
                Container(
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
                            Image.asset('assets/images/Visa_Logo.jpeg', height: 30),
                            const SizedBox(width: 5),
                            Image.asset('assets/images/MasterCard_Logo.png', height: 30),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 0.91,
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                border: Border.all(color: const Color(0xFF08143c)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Alinear elementos
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
          ],
        ),
      ),
    );
  }
}