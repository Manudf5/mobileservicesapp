import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:photo_view/photo_view.dart';
import 'package:image/image.dart' as img;
import 'package:one_context/one_context.dart';
import 'package:permission_handler/permission_handler.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Social',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/IconChat.png',
              height: 32, // Ajusta el tamaño según sea necesario
              width: 32, // Ajusta el tamaño según sea necesario
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
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

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _clientId;

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> getConversations() {
    return _firestore
        .collection('chats')
        .where('clientID', isEqualTo: _clientId)
        .snapshots()
        .map((snapshot) {
      final conversations = snapshot.docs;
      conversations.sort((a, b) {
        final aTimestamp = a.data()['lastMessageTimestamp'] as Timestamp?;
        final bTimestamp = b.data()['lastMessageTimestamp'] as Timestamp?;
        if (aTimestamp != null && bTimestamp != null) {
          return bTimestamp.compareTo(aTimestamp);
        } else {
          return 0;
        }
      });
      return conversations;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchClientId();
  }

  Future _fetchClientId() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        _clientId = user.uid;

        final QuerySnapshot<Map<String, dynamic>> querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: _clientId)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          _clientId = querySnapshot.docs.first.data()['id'];
          setState(() {});
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener el ID del proveedor: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 29,
          ),
          textAlign: TextAlign.center,
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
      backgroundColor: Colors.white,
      body: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        stream: getConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar conversaciones'));
          }

          if (snapshot.hasData) {
            final conversations = snapshot.data!;

            return ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final clientID = conversation.data()?['clientID'];
                final supplierID = conversation.data()?['supplierID'];
                final supplierName = conversation.data()?['supplierName'];
                final lastMessage = conversation.data()?['lastMessage'];
                final lastMessageTimestamp =
                    conversation.data()?['lastMessageTimestamp'] as Timestamp?;
                final unreadCount =
                    conversation.data()?['unreadCountClient'] ?? 0;
                final isUnread = unreadCount > 0;

                return ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          clientID: clientID,
                          supplierID: supplierID,
                          clientName: _clientId!,
                          supplierName: supplierName,
                          supplierProfileImageUrl: '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      // Añadido GestureDetector para la foto de perfil
                      onTap: () {
                        // Mostrar foto de perfil ampliada
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              content: FutureBuilder<String?>(
                                future: getSupplierProfileImageUrl(supplierID),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    final profileImageUrl = snapshot.data;
                                    return profileImageUrl != null
                                        ? Image.network(profileImageUrl)
                                        : Image.asset(
                                            'assets/images/ProfilePhoto_predetermined.png');
                                  } else {
                                    return const CupertinoActivityIndicator(
                                      radius: 16,
                                      color: Colors.green,
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                      child: FutureBuilder<String?>(
                        future: getSupplierProfileImageUrl(supplierID),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            final profileImageUrl = snapshot.data;
                            return CircleAvatar(
                              radius: 25,
                              backgroundImage: profileImageUrl != null
                                  ? NetworkImage(profileImageUrl)
                                  : const AssetImage(
                                      'assets/images/ProfilePhoto_predetermined.png'),
                            );
                          } else {
                            return const CupertinoActivityIndicator(
                              radius: 16,
                              color: Colors.green,
                            );
                          }
                        },
                      ),
                    ),
                    title: Text(
                      supplierName ?? '',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (conversation.data()?['lastMessageSender'] ==
                            _clientId)
                          Icon(
                            conversation.data()?['lastMessageIsRead'] == true
                                ? Icons.done_all
                                : Icons.done,
                            size: 16,
                            color: conversation.data()?['lastMessageIsRead'] ==
                                    true
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lastMessage ?? '',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatTimestamp(lastMessageTimestamp),
                          style: TextStyle(
                            color: isUnread ? Colors.green : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return const Center(
              child: CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          ));
        },
      ),
    );
  }

  Future<String?> getSupplierProfileImageUrl(String supplierID) async {
    final supplierDocSnapshot =
        await _firestore.collection('users').doc(supplierID).get();
    return supplierDocSnapshot.data()?['profileImageUrl'];
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final now = DateTime.now();
    final messageDate = timestamp.toDate();

    if (messageDate.day == now.day) {
      return DateFormat('hh:mm a').format(messageDate);
    } else if (messageDate.difference(now).inDays == -1) {
      return 'Ayer';
    } else {
      return DateFormat('dd/MM/yyyy').format(messageDate);
    }
  }
}

class ChatScreen extends StatefulWidget {
  final String clientID;
  final String supplierID;
  final String clientName;
  final String supplierName;
  final String supplierProfileImageUrl;

  const ChatScreen({
    super.key,
    required this.clientID,
    required this.supplierID,
    required this.clientName,
    required this.supplierName,
    required this.supplierProfileImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _imageMessageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _errorMessage;

  bool _showChatInput = true;
  String? _supplierProfileImageUrl;
  String _chatID = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _foundMessages = [];
  int _currentFoundMessageIndex = -1;

  // Expresiones regulares para validar el mensaje
  final RegExp _phoneRegex = RegExp(
      r'(\+?\d{1,4}[\s-]?)?(?:\d{3}[\s-]?)?\d{3}[\s-]?\d{4}|\+?(0412|0414|0424|0416|0426|0251|0252)\d{7}');
  final RegExp _emailRegex = RegExp(r'[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+');
  final RegExp _urlRegex = RegExp(
      r'(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)');
  final RegExp _cardNumberRegex =
      RegExp(r'(\d{4}[ -]?){3}\d{4}|\d{16}'); // Visa y Mastercard
  final List<String> _profanities = [
    'Coño',
    'coño',
    'Ladilla',
    'ladilla',
    'Verga',
    'verga',
  ];
  final List<String> _socialMediaKeywords = [
    '@',
    'facebook',
    'Facebook',
    'fb',
    'Fb',
    'FB',
    'instagram',
    'Instagram',
    'ig'
    'Ig'
    'IG',
    'whatsapp',
    'Whatsapp',
    'twitter',
    'Twitter',
    'gmail',
    'Gmail',
    'hotmail',
    'Hotmail',
    // Agrega aquí más palabras clave de redes sociales
  ];

  StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
      QuerySnapshot<Map<String, dynamic>>> delayedTransformer() {
    return StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        Future.delayed(const Duration(milliseconds: 100), () {
          sink.add(data);
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _chatID = '${widget.clientID}_${widget.supplierID}';
    _checkChatExistence();
    _getSupplierProfileImageUrl();
    _resetUnreadCount();
    _markMessagesAsRead();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _imageMessageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _markMessagesAsRead();
    }
  }

  Future<void> _checkChatExistence() async {
    final chatDoc = await _firestore.collection('chats').doc(_chatID).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data() as Map<String, dynamic>;
      setState(() {
        _showChatInput = chatData['talk'];
      });
    } else {
      await _createChat();
    }
  }

  Future<void> _createChat() async {
    await _firestore.collection('chats').doc(_chatID).set({
      'clientID': widget.clientID,
      'supplierID': widget.supplierID,
      'clientName': widget.clientName,
      'supplierName': widget.supplierName,
      'talk': true,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCountClient': 0,
      'unreadCountSupplier': 0,
    });

    setState(() {
      _showChatInput = true;
    });
  }

  Future<void> _resetUnreadCount() async {
    await _firestore.collection('chats').doc(_chatID).update({
      'unreadCountClient': 0,
    });
  }

  Future<void> sendMessage() async {
    final messageText = _messageController.text.trim();
  if (messageText.isEmpty) return;

  final errorMessage = _containsRestrictedContent(messageText);
  if (errorMessage != null) {
    setState(() {
      _errorMessage = errorMessage;
    });
    return;
  }

  setState(() {
    _errorMessage = null;
  });

    await _firestore
        .collection('chats')
        .doc(_chatID)
        .collection('messages')
        .add({
      'message': messageText,
      'sender': widget.clientID,
      'timestamp': FieldValue.serverTimestamp(),
      'type': '',
      'isRead': false,
    });

    await _firestore.collection('chats').doc(_chatID).update({
      'lastMessage': messageText,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCountSupplier': FieldValue.increment(1),
      'lastMessageSender': widget.clientID,
      'lastMessageIsRead': false,
    });

    _messageController.clear();
  }

  Future<void> _getSupplierProfileImageUrl() async {
    final supplierDocSnapshot =
        await _firestore.collection('users').doc(widget.supplierID).get();
    setState(() {
      _supplierProfileImageUrl = supplierDocSnapshot.data()?['profileImageUrl'];
    });
  }

  Future<void> _selectImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _showPreviewImage();
    }
  }

  Future<void> _sendImageWithMessage() async {
    if (_selectedImage != null) {
    final messageText = _imageMessageController.text.trim();
    final errorMessage = _containsRestrictedContent(messageText);
    if (errorMessage != null) {
      setState(() {
        _errorMessage = errorMessage;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

      // Comprimir la imagen antes de subirla
      final compressedImage = await _compressImage(_selectedImage!);

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('chat_images/$_chatID/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = storageRef.putFile(compressedImage);

      await uploadTask.whenComplete(() async {
        final downloadUrl = await storageRef.getDownloadURL();
        final messageText = _imageMessageController.text.trim();

        await _firestore
            .collection('chats')
            .doc(_chatID)
            .collection('messages')
            .add({
          'message': messageText,
          'imageUrl': downloadUrl,
          'sender': widget.clientID,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'image_with_message',
          'isRead': false,
        });

        await _firestore.collection('chats').doc(_chatID).update({
          'lastMessage': messageText.isNotEmpty ? messageText : 'Imagen',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'unreadCountSupplier': FieldValue.increment(1),
          'lastMessageSender': widget.clientID,
          'lastMessageIsRead': false,
        });

        setState(() {
          _selectedImage = null;
        });
        _imageMessageController.clear();
      });
    }
  }

  /// Comprime la imagen y reduce la calidad a 70.
  Future<File> _compressImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Error al decodificar la imagen');
    }

    final compressedImage = img.copyResize(
      decodedImage,
      width: (decodedImage.width * 0.7).toInt(), // Reducir el ancho en un 30%
      height: (decodedImage.height * 0.7)
          .toInt(), // Reducir la altura en un 30%
    );

    final encodedImage = img.encodeJpg(
        compressedImage,
        quality: 70); // Reducir la calidad a 70
    final compressedFile = File(imageFile.path)..writeAsBytesSync(encodedImage);
    return compressedFile;
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markMessagesAsRead() async {
    final querySnapshot = await _firestore
        .collection('chats')
        .doc(_chatID)
        .collection('messages')
        .where('sender', isEqualTo: widget.supplierID)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();

    await _firestore.collection('chats').doc(_chatID).update({
      'lastMessageIsRead': true,
      'unreadCountClient': 0,
    });
  }

  Future<void> markMessagesAsRead() async {
    await _firestore
        .collection('chats')
        .doc(_chatID)
        .collection('messages')
        .where('sender', isEqualTo: widget.supplierID)
        .where('isRead', isEqualTo: false)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });

    await _firestore.collection('chats').doc(_chatID).update({
      'unreadCountClient': 0,
    });
  }

  void _onSearchTextChanged(String text) {
    setState(() {
      _foundMessages = [];
      _currentFoundMessageIndex = -1;
    });

    if (text.isEmpty) {
      return;
    }

    _firestore
        .collection('chats')
        .doc(_chatID)
        .collection('messages')
        .get()
        .then((querySnapshot) {
      for (var message in querySnapshot.docs) {
        if (message['message'] != null &&
            message['message'].toLowerCase().contains(text.toLowerCase())) {
          setState(() {
            _foundMessages.add(message);
          });
        }
      }
      if (_foundMessages.isNotEmpty) {
        setState(() {
          _currentFoundMessageIndex = 0;
        });
        _scrollToMessage(_foundMessages[0]);
      }
    });
  }

  void _scrollToMessage(QueryDocumentSnapshot<Map<String, dynamic>> message) {
    _scrollController.animateTo(
      _getMessagePosition(message),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  double _getMessagePosition(
      QueryDocumentSnapshot<Map<String, dynamic>> message) {
    final messageIndex = _foundMessages.indexOf(message);
    if (messageIndex == -1) {
      return _scrollController.position.maxScrollExtent;
    } else {
      return _scrollController.position.maxScrollExtent -
          (messageIndex *
              80); // Ajusta 80 según el tamaño promedio de tus mensajes
    }
  }

  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _handleCameraOption();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _selectImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCameraOption() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _openCamera();
    } else {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        _openCamera();
      } else {
        _showCameraPermissionDialog();
      }
    }
  }

  Future<void> _showCameraPermissionDialog() async {
    OneContext().showDialog(
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 50, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Solicitud de acceso a la cámara',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Para poder tomar fotos y enviarlas, necesitamos acceso a la cámara de tu dispositivo. ¿Deseas permitir el acceso?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Permitir'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      OneContext().showSnackBar(
                        builder: (_) => const SnackBar(
                          content: Text('Acceso denegado a la cámara'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Denegar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _showPreviewImage();
    }
  }

  void _showMultimediaScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultimediaScreen(chatID: _chatID),
      ),
    );
  }

  // Función para validar el contenido del mensaje
  String? _containsRestrictedContent(String message) {
  String messageLower = message.toLowerCase();

  if (_phoneRegex.hasMatch(message)) {
    return 'El mensaje contiene un número de teléfono no permitido.';
  }

  if (_emailRegex.hasMatch(message)) {
    return 'El mensaje contiene una dirección de correo electrónico no permitida.';
  }

  if (_urlRegex.hasMatch(message)) {
    return 'El mensaje contiene una URL no permitida.';
  }

  if (_cardNumberRegex.hasMatch(message)) {
    return 'El mensaje contiene un número de tarjeta no permitido.';
  }

  for (String profanity in _profanities) {
    if (messageLower.contains(profanity)) {
      return 'El mensaje contiene lenguaje inapropiado.';
    }
  }

  for (String keyword in _socialMediaKeywords) {
    if (messageLower.contains(keyword)) {
      return 'El mensaje contiene referencias a redes sociales no permitidas.';
    }
  }

  return null;
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                onChanged: _onSearchTextChanged,
                decoration: const InputDecoration(
                  hintText: 'Buscar en la conversación...',
                  border: InputBorder.none,
                ),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: _supplierProfileImageUrl != null
                        ? NetworkImage(_supplierProfileImageUrl!)
                        : const AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png')
                            as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.supplierName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'Ver perfil',
                child: Text('Ver perfil'),
              ),
              const PopupMenuItem<String>(
                value: 'Multimedia',
                child: Text('Multimedia'),
              ),
              const PopupMenuItem<String>(
                value: 'Reportar usuario',
                child: Text('Reportar usuario'),
              ),
            ],
            onSelected: (value) {
              if (value == 'Ver perfil') {
                // Navegar a la pantalla de perfil
              } else if (value == 'Multimedia') {
                _showMultimediaScreen();
              } else if (value == 'Reportar usuario') {
                // Navegar a la pantalla de reporte de usuario
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSearching)
              if (_foundMessages.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No se encontraron mensajes'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        onPressed: _currentFoundMessageIndex > 0
                            ? () {
                                setState(() {
                                  _currentFoundMessageIndex--;
                                });
                                _scrollToMessage(
                                    _foundMessages[_currentFoundMessageIndex]);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      Text('${_currentFoundMessageIndex + 1}/'
                          '${_foundMessages.length}'),
                      IconButton(
                        onPressed: _currentFoundMessageIndex <
                                _foundMessages.length - 1
                            ? () {
                                setState(() {
                                  _currentFoundMessageIndex++;
                                });
                                _scrollToMessage(
                                    _foundMessages[_currentFoundMessageIndex]);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('chats')
                    .doc(_chatID)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots()
                    .transform(delayedTransformer()),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error al cargar mensajes'));
                  }

                  if (snapshot.hasData) {
                    final messages = snapshot.data!.docs;

                    final messagesByDate = <DateTime, List<dynamic>>{};
                    for (var message in messages) {
                      final timestamp = message.data()['timestamp'];
                      if (timestamp != null) {
                        final messageDate = DateTime(
                          (timestamp as Timestamp).toDate().year,
                          (timestamp).toDate().month,
                          (timestamp).toDate().day,
                        );

                        if (!messagesByDate.containsKey(messageDate)) {
                          messagesByDate[messageDate] = [];
                        }

                        messagesByDate[messageDate]!.add(message);
                      } else {
                        // Si el timestamp es null, añadimos el mensaje a la fecha actual
                        final now = DateTime.now();
                        final todayDate =
                            DateTime(now.year, now.month, now.day);
                        if (!messagesByDate.containsKey(todayDate)) {
                          messagesByDate[todayDate] = [];
                        }
                        messagesByDate[todayDate]!.add(message);
                      }
                    }

                    final messageWidgets = <Widget>[];
                    messagesByDate.forEach((date, messages) {
                      for (var message in messages) {
                        messageWidgets.add(_buildMessageBubble(message));
                      }
                      messageWidgets.add(_buildDateSeparator(date));
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: messageWidgets.length,
                      itemBuilder: (context, index) {
                        return messageWidgets[index];
                      },
                    );
                  }
                  return const Center(
                      child: CupertinoActivityIndicator(
                    radius: 16,
                    color: Colors.green,
                  ));
                },
              ),
            ),
            if (_showChatInput)
              Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  decoration: const BoxDecoration(
    color: Colors.white,
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _showImageSourceMenu();
                    },
                    icon: Image.asset(
                      'assets/images/IconGallery.png',
                      height: 24,
                      width: 24,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        hintStyle: TextStyle(color: Colors.blueGrey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () {
          sendMessage();
        },
        icon: Image.asset(
          'assets/images/IconSend.png',
          height: 40,
          width: 40,
        ),
      ),
    ],
  ),
)
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      QueryDocumentSnapshot<Map<String, dynamic>> message) {
    final data = message.data();
    final messageText = data['message'] as String? ?? '';
    final sender = data['sender'] as String? ?? '';
    final messageType = data['type'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final isRead = data['isRead'] as bool? ?? false;

    Color? messageColor =
        sender == widget.clientID ? Colors.green[100] : Colors.grey[200]!;

    String formattedTimestamp = '';
    if (data['timestamp'] != null) {
      formattedTimestamp = DateFormat('hh:mm a')
          .format((data['timestamp'] as Timestamp).toDate());
    } else {
      formattedTimestamp = DateFormat('hh:mm a').format(DateTime.now());
    }

    if (messageType == 'image_with_message' && imageUrl != null) {
      return Align(
        alignment: sender == widget.clientID
            ? Alignment.bottomRight
            : Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: messageColor,
          ),
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showFullScreenImage(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (messageText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  messageText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (formattedTimestamp.isNotEmpty)
                    Text(
                      formattedTimestamp,
                      style: const TextStyle(
                        color: Color(0xFF08143C),
                        fontSize: 9,
                      ),
                    ),
                  if (sender == widget.clientID) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: isRead ? Colors.blue : Colors.grey,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Align(
        alignment: sender == widget.clientID
            ? Alignment.bottomRight
            : Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: messageColor,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double availableWidth = constraints.maxWidth - 20;
              availableWidth = availableWidth > 280 ? 280 : availableWidth;

              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: availableWidth),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            messageText,
                            style: TextStyle(
                              color: sender == widget.clientID
                                  ? Colors.black
                                  : Colors.black,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (formattedTimestamp.isNotEmpty)
                                Text(
                                  formattedTimestamp,
                                  style: TextStyle(
                                    color: sender == widget.clientID
                                        ? const Color(0xFF08143C)
                                        : const Color(0xFF08143C),
                                    fontSize: 9,
                                  ),
                                ),
                              if (sender == widget.clientID) ...[
                                const SizedBox(width: 5),
                                Icon(
                                  isRead ? Icons.done_all : Icons.done,
                                  size: 16,
                                  color: isRead ? Colors.blue : Colors.grey,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    String dateText;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      dateText = 'Hoy';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      dateText = 'Ayer';
    } else {
      dateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPreviewImage() async {
  if (_selectedImage != null) {
    String? localErrorMessage;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _imageMessageController,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(10),
                        ),
                        maxLines: 3,
                      ),
                    ),
                    if (localErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          localErrorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                    if (_selectedImage != null)
  ClipRRect(
    borderRadius: BorderRadius.circular(20), // Define el radio de los bordes redondeados
    child: SizedBox(
      child: Image.file(_selectedImage!),
    ),
  ),
                    const SizedBox(height: 10),
                    
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _imageMessageController.clear();
                  },
                  child: const Text('Cancelar'),
                ),
                IconButton(
                  onPressed: () {
                    final errorMessage = _containsRestrictedContent(_imageMessageController.text.trim());
                    if (errorMessage != null) {
                      setState(() {
                        localErrorMessage = errorMessage;
                      });
                    } else {
                      _sendImageWithMessage();
                      Navigator.of(context).pop();
                    }
                  },
                  icon: Image.asset(
                    'assets/images/IconSend.png',
                    height: 40,
                    width: 40,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    // Limpia _selectedImage después de cerrar el diálogo
    setState(() {
      _selectedImage = null;
    });
  }
}
}

class MultimediaScreen extends StatelessWidget {
  final String chatID;

  const MultimediaScreen({super.key, required this.chatID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Archivos multimedia'),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatID)
            .collection('messages')
            .where('imageUrl', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar imágenes'));
          }

          if (snapshot.hasData) {
            final images = snapshot.data!.docs.where((image) {
              final message = image.data();
              return message.containsKey('imageUrl') &&
                  message['imageUrl'] != null &&
                  message['imageUrl'] != '';
            }).toList();

            if (images.isEmpty) {
              return const Center(child: Text('No hay archivos multimedia'));
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final imageUrl = images[index]['imageUrl'] as String;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          body: Center(
                            child: PhotoView(
                              imageProvider: NetworkImage(imageUrl),
                              backgroundDecoration:
                                  const BoxDecoration(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                );
              },
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
