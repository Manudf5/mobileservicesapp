import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:photo_view/photo_view.dart';

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

  bool _showChatInput = true;
  String? _supplierProfileImageUrl;
  String _chatID = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _foundMessages = [];
  int _currentFoundMessageIndex = -1;

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

  void sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) return;

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
      final storageRef = firebase_storage.FirebaseStorage.instance.ref().child(
          'chat_images/$_chatID/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = storageRef.putFile(_selectedImage!);

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
          (messageIndex * 80); // Ajusta 80 según el tamaño promedio de tus mensajes
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error al cargar mensajes'));
                  }

                  if (snapshot.hasData) {
                    final messages = snapshot.data!.docs;

                    final messagesByDate = <DateTime, List<dynamic>>{};
                    for (var message in messages) {
                      final timestamp =
                          message.data()['timestamp'] as Timestamp;
                      final messageDate = DateTime(
                        timestamp.toDate().year,
                        timestamp.toDate().month,
                        timestamp.toDate().day,
                      );

                      if (!messagesByDate.containsKey(messageDate)) {
                        messagesByDate[messageDate] = [];
                      }

                      messagesByDate[messageDate]!.add(message);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                _selectImage(ImageSource.gallery);
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
                                  hintStyle: TextStyle(color: Colors.grey),
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
              ),
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
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: Image.file(_selectedImage!),
                  ),
                  const SizedBox(height: 10),
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _selectedImage = null;
                  });
                  _imageMessageController.clear();
                },
                child: const Text('Cancelar'),
              ),
              IconButton(
                onPressed: () {
                  _sendImageWithMessage();
                  Navigator.of(context).pop();
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
    }
  }
}

class MultimediaScreen extends StatelessWidget {
  final String chatID;

  const MultimediaScreen({Key? key, required this.chatID}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Archivos multimedia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
                              backgroundDecoration: const BoxDecoration(
                                  color: Colors.black),
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