// social.dart
import 'package:flutter/material.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Social', 
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28, 
          ),
          textAlign: TextAlign.center, 
        ),
        actions: [
          IconButton(
            icon: Image.asset('assets/images/IconChat.png', 
              height: 32, // Ajusta el tamaño según sea necesario
              width: 32, // Ajusta el tamaño según sea necesario
            ), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white, // Fondo blanco para la pantalla Social
      body: const Center(
        child: Text('Pantalla social'),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Mensajes', 
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24, 
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Retrocede a la pantalla Social
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Acción al presionar el ícono de lupa (opcional)
            },
          ),
        ],
      ),
      backgroundColor: Colors.white, // Fondo blanco para la pantalla Chat
      body: const Center(
        child: Text('Pantalla de chat'),
      ),
    );
  }
}