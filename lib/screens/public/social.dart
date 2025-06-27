import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:mobileservicesapp/screens/public/profile.dart';
import 'package:photo_view/photo_view.dart';
import 'package:image/image.dart' as img;
import 'package:one_context/one_context.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SocialScreenState createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _clientId;
  Future<DocumentSnapshot>? _supplierProfileFuture;
  int _unreadChatsCount = 0;

  // Lista para almacenar los controladores de Screenshot
  final List<ScreenshotController> _screenshotControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchClientId();
    _fetchUnreadChatsCount();
  }

  Future<void> _fetchClientId() async {
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

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    List<Map<String, dynamic>> posts = [];
    if (_clientId == null) return posts;

    final QuerySnapshot suppliersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    for (var supplier in suppliersSnapshot.docs) {
      final followerSnapshot =
          await supplier.reference.collection('followers').doc(_clientId).get();

      if (followerSnapshot.exists) {
        // Get the profileImageUrl from the 'users' collection
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(supplier.id)
            .get();
        final profileImageUrl = userSnapshot.data()?['profileImageUrl'];

        final publicationsSnapshot =
            await supplier.reference.collection('publications').get();

        for (var post in publicationsSnapshot.docs) {
          final likesSnapshot = await post.reference.collection('likes').get();
          final isLiked = likesSnapshot.docs.any((doc) => doc.id == _clientId);
          posts.add({
            'PostImageUrl': post['PostImageUrl'],
            'description': post['description'],
            'publicationDate': post['publicationDate'].toDate(),
            'serviceName': post['serviceName'],
            'name': supplier['name'],
            'supplierId': supplier.id,
            'postId': post.id,
            'isLiked': isLiked,
            'likesCount': likesSnapshot.docs.length,
            // Add profileImageUrl to the post data
            'profileImageUrl': profileImageUrl,
          });
        }
      }
    }

    return posts;
  }

  Future<void> _toggleLike(
      String supplierId, String postId, bool isLiked) async {
    final DocumentReference likesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(supplierId)
        .collection('publications')
        .doc(postId)
        .collection('likes')
        .doc(_clientId);

    if (isLiked) {
      await likesRef.delete();
    } else {
      await likesRef.set({
        'likedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      return 'Hace ${(difference.inDays / 7).floor()} semanas';
    } else if (difference.inDays < 365) {
      return 'Hace ${(difference.inDays / 30).floor()} meses';
    } else {
      return 'Hace ${(difference.inDays / 365).floor()} años';
    }
  }

  void _showOptionsBottomSheet(
      BuildContext context, String supplierId, String postId, int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Ver perfil'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileViewScreen(supplierId: supplierId),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Compartir'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePost(context, supplierId, postId, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Reportar publicación'),
                onTap: () {
                  Navigator.pop(context);
                  showPublicationReportBottomSheet(context, supplierId, postId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSupplierProfileBottomSheet(
      BuildContext context, String supplierId, String name) {
    _supplierProfileFuture =
        FirebaseFirestore.instance.collection('users').doc(supplierId).get();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 1.0,
            maxChildSize: 1.0,
            expand: false,
            builder: (BuildContext context, ScrollController scrollController) {
              return FutureBuilder<DocumentSnapshot>(
                future: _supplierProfileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child:
                            Text('No se encontró información del proveedor'));
                  }

                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                  String profileImageUrl = userData['profileImageUrl'] ??
                      'assets/images/ProfilePhoto_predetermined.png';
                  String coverImageUrl = userData['coverImageUrl'] ?? '';
                  String fullName =
                      '${userData['name']} ${userData['lastName']}';
                  String id = userData['id'] ?? '';
                  String bio = userData['bio'] ?? 'Sin biografía';

                  return Stack(
                    children: [
                      // Cover image
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: // Aqui no se ejecuta ningun codigo al hacer tap
                            ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(27.0),
                            topRight: Radius.circular(27.0),
                            bottomLeft: Radius.circular(13.0),
                            bottomRight: Radius.circular(13.0),
                          ),
                          child: coverImageUrl.isEmpty
                              ? Container(
                                  height: 165,
                                  color: const Color(0xFF08143c),
                                )
                              : Container(
                                  height: 165,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(coverImageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Profile image
                      Positioned(
                        top: 105,
                        left: 20,
                        child: // Aqui no se ejecuta ningun codigo al hacer tap
                            Hero(
                          tag: 'profileImage',
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4.0,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage:
                                  profileImageUrl.startsWith('http')
                                      ? NetworkImage(profileImageUrl)
                                      : AssetImage(profileImageUrl)
                                          as ImageProvider,
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 141, left: 23.0, right: 23.0),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Profile button
                            Align(
                              alignment: Alignment.topRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileViewScreen(
                                          supplierId: supplierId),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 1),
                                  minimumSize: const Size(120.0, 41.0),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  side: const BorderSide(
                                      color: Colors.white, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                label: const Text('Ver perfil',
                                    style: TextStyle(fontSize: 15)),
                              ),
                            ),
                            const SizedBox(height: 30.0),
                            // Supplier name
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        FutureBuilder<List<int>>(
                                          future: _getTaskCounts(supplierId),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData &&
                                                snapshot.data![0] < 5) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[800],
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: const Text(
                                                  'NUEVO',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ID: $id',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                FutureBuilder<List<dynamic>>(
                                  future:
                                      _getAverageClientEvaluation(supplierId),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const CupertinoActivityIndicator(
                                        radius: 16,
                                        color: Colors.green,
                                      );
                                    }
                                    if (snapshot.hasData) {
                                      String averageEvaluation =
                                          snapshot.data![0];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5.0,
                                          horizontal: 10.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                          border: Border.all(
                                            color: const Color(0xFF08143C),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 18.0,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4.0),
                                            Text(
                                              averageEvaluation,
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Biography
                            Container(
                              margin:
                                  const EdgeInsets.only(top: 10, bottom: 20),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.0,
                                ),
                              ),
                              width: double.infinity,
                              child: Text(
                                bio,
                                style: const TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void showPublicationReportBottomSheet(
      BuildContext context, String supplierId, String postId) {
    String selectedReason = '';
    String otherReason = '';
    bool isOtherSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reportar publicación',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        'Comportamiento inapropiado',
                        'Estafa',
                        'Genera desconfianza',
                        'Contenido indebido',
                        'Información falsa',
                        'Incitación al odio',
                        'Ventas ilícitas',
                        'Spam',
                        'Otro',
                      ].map((String reason) {
                        return ChoiceChip(
                          label: Text(
                            reason,
                            style: TextStyle(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          selectedColor: selectedReason == reason
                              ? const Color(0xFF08143C)
                              : null,
                          selected: selectedReason == reason,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedReason = selected ? reason : '';
                              isOtherSelected = reason == 'Otro';
                            });
                          },
                          // Add this to change checkmark color
                          selectedShadowColor: Colors.transparent,
                          disabledColor: Colors.transparent,
                          checkmarkColor: Colors.green,
                        );
                      }).toList(),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        onChanged: (value) {
                          otherReason = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Especifique el motivo',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: 'Ingresa el motivo',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.blueGrey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                                const BorderSide(color: Color(0xFF08143c)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el motivo';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ca424),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () => _submitPublicationReport(
                            selectedReason, otherReason, supplierId, postId),
                        child: const Text('Enviar reporte'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _submitPublicationReport(String selectedReason, String otherReason,
      String supplierId, String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado')),
      );
      return;
    }

    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    if (reporterDoc.docs.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error: No se pudo obtener la información del usuario')),
      );
      return;
    }

    final reporterData = reporterDoc.docs.first.data();

    // Obtener el nombre y apellido del usuario reportado
    final reportedUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(supplierId)
        .get();

    if (reportedUserDoc.exists) {
      final reportedUserData = reportedUserDoc.data()!;
      final reportedUserName =
          '${reportedUserData['name']} ${reportedUserData['lastName']}';

      final reportData = {
        'timestamp': FieldValue.serverTimestamp(),
        'reportedUserName':
            reportedUserName, // Usar el nombre del usuario reportado
        'reportedUserId': supplierId,
        'reason': selectedReason == 'Otro' ? otherReason : selectedReason,
        'category': 'Publicación',
        'reporterName': '${reporterData['name']} ${reporterData['lastName']}',
        'reporterId': reporterDoc.docs.first.id,
        'postId': postId,
      };

      // Generar el ID del documento
      final DateTime now = DateTime.now();
      final String documentId =
          '${supplierId}_${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';

      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(documentId)
            .set(reportData);
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado')),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el reporte')),
        );
      }
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: No se pudo obtener la información del usuario reportado')),
      );
    }
  }

  Future<List<int>> _getTaskCounts(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();
    int completedTasks = 0;
    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID &&
          taskDoc.data()['state'] == 'Finalizada') {
        completedTasks++;
      }
    }
    return [completedTasks];
  }

  Future<List<dynamic>> _getAverageClientEvaluation(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();
    double totalEvaluation = 0;
    int evaluationCount = 0;
    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID &&
          taskDoc.data()['clientEvaluation'] != null) {
        totalEvaluation += taskDoc.data()['clientEvaluation'];
        evaluationCount++;
      }
    }
    if (evaluationCount == 0) return ['N/A', 0];
    return [
      (totalEvaluation / evaluationCount).toStringAsFixed(1),
      evaluationCount
    ];
  }

  // Función para compartir el post
  Future<void> _sharePost(
      BuildContext context, String supplierId, String postId, int index) async {
    try {
      // Tomar captura del widget
      final image = await _screenshotControllers[index].capture();

      if (image != null) {
        // Guardar la imagen temporalmente
        final directory = Directory.systemTemp;
        final imagePath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
        File imageFile = await File(imagePath).writeAsBytes(image);

        // Compartir la imagen usando share_plus
        await Share.shareXFiles([XFile(imageFile.path)],
            text:
                '¡Mira esta publicación en MSA! Descarga la app disponible para Android y IOS');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al compartir el post: $e');
      }
      // Manejar el error, por ejemplo, mostrando un mensaje al usuario
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al compartir la publicación')),
      );
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

  Future<void> _fetchUnreadChatsCount() async {
    String combinedId = await _getCombinedIdFromFirestore(
        FirebaseAuth.instance.currentUser!.uid);

    FirebaseFirestore.instance
        .collection('chats')
        .where('clientID', isEqualTo: combinedId)
        .where('unreadCountClient', isGreaterThan: 0)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _unreadChatsCount = snapshot.docs.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: Image.asset(
                    'assets/images/IconChat.png',
                    height: 40,
                    width: 40,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatListScreen()),
                    );
                  },
                ),
                if (_unreadChatsCount > 0)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: Text(
                      '$_unreadChatsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CupertinoActivityIndicator(
                radius: 16,
                color: Colors.green,
              ));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aun no sigues a nadie'));
            } else {
              final posts = snapshot.data!;
              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  // Crear un nuevo controlador de Screenshot para cada publicación
                  _screenshotControllers.add(ScreenshotController());
                  final post = posts[index];
                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setPostState) {
                      // Envolver el Card con Screenshot
                      return Screenshot(
                        controller: _screenshotControllers[index],
                        child: Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _showSupplierProfileBottomSheet(
                                        context,
                                        post['supplierId'],
                                        post['name'],
                                      ),
                                      child: CircleAvatar(
                                        radius: 25,
                                        backgroundImage: post[
                                                    'profileImageUrl'] !=
                                                null
                                            ? NetworkImage(
                                                post['profileImageUrl'])
                                            : const AssetImage(
                                                'assets/images/ProfilePhoto_predetermined.png'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            post['serviceName'],
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_horiz),
                                      onPressed: () => _showOptionsBottomSheet(
                                        context,
                                        post['supplierId'],
                                        post['postId'],
                                        index, // Pasar el índice aquí
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Imagen con doble tap para dar like
                              GestureDetector(
                                onDoubleTap: () async {
                                  // Dar like al post
                                  await _toggleLike(post['supplierId'],
                                      post['postId'], post['isLiked']);
                                  setPostState(() {
                                    post['isLiked'] = !post['isLiked'];
                                    post['likesCount'] +=
                                        post['isLiked'] ? 1 : -1;
                                  });
                                  // Mostrar feedback visual (opcional)
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(post['isLiked']
                                          ? '¡Te gusta!'
                                          : 'No te gusta'),
                                      duration:
                                          const Duration(milliseconds: 500),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: CachedNetworkImage(
                                    imageUrl: post['PostImageUrl'],
                                    placeholder: (context, url) => const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${post['name']}:', // Nombre y apellido del supplier en negrita
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(
                                        height:
                                            4), // Espacio entre el nombre y la descripción
                                    Text(
                                      post[
                                          'description'], // Descripción del post
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 1),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatTimeAgo(
                                              post['publicationDate']),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${post['likesCount']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                post['isLiked']
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: post['isLiked']
                                                    ? Colors.red
                                                    : null,
                                                size: post['isLiked'] ? 30 : 25,
                                              ),
                                              onPressed: () async {
                                                await _toggleLike(
                                                  post['supplierId'],
                                                  post['postId'],
                                                  post['isLiked'],
                                                );
                                                setPostState(() {
                                                  post['isLiked'] =
                                                      !post['isLiked'];
                                                  post['likesCount'] +=
                                                      post['isLiked'] ? 1 : -1;
                                                });
                                              },
                                            ),
                                            // Aquí va el nuevo botón del avioncito de papel
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.send_rounded),
                                              // Puedes cambiar el icono si lo deseas
                                              onPressed: () {
                                                _sharePost(
                                                    context,
                                                    post['supplierId'],
                                                    post['postId'],
                                                    index);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class ProfileViewScreen extends StatefulWidget {
  final String supplierId;

  const ProfileViewScreen({super.key, required this.supplierId});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<Offset> _slideAnimation;
  String clientIDString = "";
  String clientName = "";
  late Future<void> _initFuture;
  // ignore: unused_field
  bool _isFollowing = false;

  // Variable para almacenar la URL de la imagen de portada
  String? _coverImageUrl;

  final Map<String, Color> _labelColors = {};

  // Método para obtener un color aleatorio para un servicio
  Color _getLabelColor(String service) {
    if (_labelColors.containsKey(service)) {
      return _labelColors[service]!;
    } else {
      Color randomColor = Color(Random().nextInt(0xFFFFFFFF))
          .withOpacity(0.7); // Ajusta la opacidad según sea necesario
      _labelColors[service] = randomColor;
      return randomColor;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initFuture = _initializeData();
  }

  Future<void> _initializeData() async {
    await _getUserInfo();
    await _getUserCoverImage();
  }

  Future<void> _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          clientName = '${doc['name']} ${doc['lastName']}';
          clientIDString = doc['id'];
        });
      }
    }
  }

  Future<void> _getUserCoverImage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.supplierId)
        .get();
    if (userDoc.exists) {
      setState(() {
        _coverImageUrl = userDoc.data()?['coverImageUrl'];
      });
    }
  }

  Future<Map<String, dynamic>> _getSupplierRatings(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    int totalRatings = 0;
    double totalScore = 0;
    Map<int, int> ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID &&
          taskDoc.data()['clientEvaluation'] != null) {
        int rating = taskDoc.data()['clientEvaluation'] as int;
        totalRatings++;
        totalScore += rating;
        ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
      }
    }

    double averageRating = totalRatings > 0 ? totalScore / totalRatings : 0;

    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingCounts': ratingCounts,
    };
  }

  // Nuevo método para mostrar la lista de publicaciones en un BottomSheet
  void _showPublicationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          // Ajustar la altura del contenedor
          height: MediaQuery.of(context).size.height *
              0.60, // 60% de la altura de la pantalla
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Titulo del BottomSheet
              const Text(
                'Todas las publicaciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // GridView para mostrar las publicaciones
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.supplierId)
                      .collection('publications')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CupertinoActivityIndicator(
                          radius: 20,
                          color: Colors.green,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No hay publicaciones disponibles'),
                      );
                    }

                    List<QueryDocumentSnapshot> publications =
                        snapshot.data!.docs;

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: publications.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImagePreviewScreen(
                                  imageUrl: publications[index][
                                      'PostImageUrl'], // Pasa la URL de la imagen
                                  isCoverImage: false,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            // Agrega esquinas redondeadas al contenedor de la imagen
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(
                                    publications[index]['PostImageUrl']),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkFollowStatus() async {
    if (clientIDString.isNotEmpty) {
      final followDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.supplierId)
          .collection('followers')
          .doc(clientIDString)
          .get();

      setState(() {
        _isFollowing = followDoc.exists;
      });
    }
  }

  Future<bool> _toggleFollow() async {
    if (clientIDString.isEmpty) return false;

    final followersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.supplierId)
        .collection('followers');

    final followDoc = await followersRef.doc(clientIDString).get();
    final isCurrentlyFollowing = followDoc.exists;

    if (!isCurrentlyFollowing) {
      // Seguir al supplier
      await followersRef.doc(clientIDString).set({
        'followedAt': FieldValue.serverTimestamp(),
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Empezaste a seguir a este agente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // Dejar de seguir
      await followersRef.doc(clientIDString).delete();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Has dejado de seguir a este agente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return !isCurrentlyFollowing;
  }

  Future<void> _showUnfollowDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '¿Dejar de seguir a este agente?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: const Text(
            'Ya no podrás visualizar sus publicaciones en el apartado de Social',
          ),
          actionsPadding: EdgeInsets.zero,
          actions: [
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.zero,
                            topLeft: Radius.zero,
                            topRight: Radius.zero,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF08143C),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.grey,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.zero,
                            bottomRight: Radius.circular(20),
                            topLeft: Radius.zero,
                            topRight: Radius.zero,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF08143C),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUserReportBottomSheet() {
    String selectedReason = '';
    String otherReason = '';
    bool isOtherSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reportar usuario',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        'Comportamiento inapropiado',
                        'Impuntual',
                        'Pésimo servicio',
                        'Estafa',
                        'Deficit en herramientas de trabajo',
                        'Genera desconfianza',
                        'Irresponsable',
                        'Contenido indebido',
                        'Información falsa',
                        'Dificultad al pagar',
                        'Incitación negativa',
                        'Poca experiencia laboral',
                        'Ventas ilícitas',
                        'Spam',
                        'Otro',
                      ].map((String reason) {
                        return ChoiceChip(
                          label: Text(
                            reason,
                            style: TextStyle(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          selectedColor: selectedReason == reason
                              ? const Color(0xFF08143C)
                              : null,
                          selected: selectedReason == reason,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedReason = selected ? reason : '';
                              isOtherSelected = reason == 'Otro';
                            });
                          },
                          // Add this to change checkmark color
                          selectedShadowColor: Colors.transparent,
                          disabledColor: Colors.transparent,
                          checkmarkColor: Colors.green,
                        );
                      }).toList(),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        onChanged: (value) {
                          otherReason = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Especifique el motivo',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: 'Ingresa el motivo',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.blueGrey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                                const BorderSide(color: Color(0xFF08143c)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el motivo';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ca424),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () =>
                            _submitUserReport(selectedReason, otherReason),
                        child: const Text('Enviar reporte'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _submitUserReport(String selectedReason, String otherReason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado')),
      );
      return;
    }

    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    if (reporterDoc.docs.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error: No se pudo obtener la información del usuario')),
      );
      return;
    }

    final reporterData = reporterDoc.docs.first.data();

    // Obtener el nombre y apellido del usuario reportado
    final reportedUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.supplierId)
        .get();

    if (reportedUserDoc.exists) {
      final reportedUserData = reportedUserDoc.data()!;
      final reportedUserName =
          '${reportedUserData['name']} ${reportedUserData['lastName']}';

      final reportData = {
        'timestamp': FieldValue.serverTimestamp(),
        'reportedUserName':
            reportedUserName, // Usar el nombre del usuario reportado
        'reportedUserId': widget.supplierId,
        'reason': selectedReason == 'Otro' ? otherReason : selectedReason,
        'category': 'Usuario',
        'reporterName': '${reporterData['name']} ${reporterData['lastName']}',
        'reporterId': reporterDoc.docs.first.id,
      };

      // Generar el ID del documento
      final DateTime now = DateTime.now();
      final String documentId =
          '${widget.supplierId}_${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';

      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(documentId)
            .set(reportData);
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado')),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el reporte')),
        );
      }
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: No se pudo obtener la información del usuario reportado')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Perfil del agente',
          style: TextStyle(color: Colors.black, fontSize: 20),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (String result) {
              if (result == 'Reportar usuario') {
                _showUserReportBottomSheet();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Reportar usuario',
                child: Text('Reportar usuario'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CupertinoActivityIndicator(
              radius: 20,
              color: Colors.green,
            ));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return SingleChildScrollView(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.supplierId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CupertinoActivityIndicator(
                    radius: 20,
                    color: Colors.green,
                  ));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Proveedor no encontrado'));
                }

                final supplierData =
                    snapshot.data!.data() as Map<String, dynamic>;

                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () {
                              if (_coverImageUrl != null &&
                                  _coverImageUrl!.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImagePreviewScreen(
                                      imageUrl: _coverImageUrl!,
                                      isCoverImage: true,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(13.0),
                                bottomRight: Radius.circular(13.0),
                              ),
                              child: _coverImageUrl == null ||
                                      _coverImageUrl!.isEmpty
                                  ? Container(
                                      height: 165,
                                      color: const Color(0xFF08143c),
                                    )
                                  : Container(
                                      height: 165,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: NetworkImage(_coverImageUrl!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                            ).animate().fadeIn().slideY(),
                          ),
                          Positioned(
                            top: 105,
                            left: 20,
                            child: GestureDetector(
                              onTap: () {
                                final profileImageUrl =
                                    supplierData['profileImageUrl'];
                                if (profileImageUrl != null &&
                                    profileImageUrl.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImagePreviewScreen(
                                        imageUrl: profileImageUrl,
                                        isCoverImage: false,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Hero(
                                tag: 'profileImage',
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4.0,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundImage: supplierData[
                                                'profileImageUrl'] !=
                                            null
                                        ? NetworkImage(
                                            supplierData['profileImageUrl'])
                                        : const AssetImage(
                                                'assets/images/ProfilePhoto_predetermined.png')
                                            as ImageProvider,
                                  ),
                                ),
                              ).animate().fade().scale(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 141, left: 23.0, right: 23.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Espacio vacío para empujar el botón a la derecha
                              const SizedBox(width: 250),
                              Expanded(
                                child: StatefulBuilder(
                                  builder: (BuildContext context,
                                      StateSetter setState) {
                                    return FutureBuilder<bool>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.supplierId)
                                          .collection('followers')
                                          .doc(clientIDString)
                                          .get()
                                          .then((doc) => doc.exists),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const CupertinoActivityIndicator();
                                        }
                                        bool isFollowing =
                                            snapshot.data ?? false;
                                        return TextButton.icon(
                                          onPressed: () async {
                                            if (isFollowing) {
                                              await _showUnfollowDialog();
                                            }
                                            bool newFollowStatus =
                                                await _toggleFollow();
                                            setState(() {
                                              isFollowing = newFollowStatus;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            backgroundColor: isFollowing
                                                ? Colors.white
                                                : Colors.green,
                                            foregroundColor: isFollowing
                                                ? Colors.green
                                                : Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 1),
                                            minimumSize:
                                                const Size(120.0, 41.0),
                                            textStyle: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            side: BorderSide(
                                                color: isFollowing
                                                    ? Colors.green
                                                    : Colors.white,
                                                width: 2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                          ),
                                          icon: Icon(
                                            isFollowing
                                                ? Icons.check
                                                : Icons.person_add,
                                            size: 20,
                                          ),
                                          label: Text(
                                            isFollowing
                                                ? 'Siguiendo'
                                                : 'Seguir',
                                            style:
                                                const TextStyle(fontSize: 15),
                                          ),
                                        ).animate().fade().scale();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 35.0),
                          Row(
                            children: [
                              Text(
                                '${supplierData['name']} ${supplierData['lastName']}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              if (supplierData['verified'] == true)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 22,
                                ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      FutureBuilder<List<int>>(
                                        future:
                                            _getTaskCounts(widget.supplierId),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data![0] < 5) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green[800],
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: const Text(
                                                'NUEVO',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ID: ${widget.supplierId}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          _buildFollowerCount(),
                          const SizedBox(height: 10),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.supplierId)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CupertinoActivityIndicator(
                                  radius: 16,
                                  color: Colors.green,
                                );
                              }
                              if (snapshot.hasData && snapshot.data!.exists) {
                                String? bio =
                                    snapshot.data!.get('bio') as String?;
                                if (bio != null && bio.isNotEmpty) {
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        top: 10, bottom: 20),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.0,
                                      ),
                                    ),
                                    width: double.infinity,
                                    child: Text(
                                      bio,
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return const SizedBox
                                  .shrink(); // No mostrar el container si no hay biografía
                            },
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<int>>(
                            future: _getTaskCounts(widget.supplierId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CupertinoActivityIndicator(
                                  radius: 16,
                                  color: Colors.green,
                                );
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }
                              if (snapshot.hasData) {
                                List<int> taskCounts = snapshot.data!;
                                int completedTasks = taskCounts[0];
                                int pendingTasks = taskCounts[1];
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF08143C),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              size: 20.0,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4.0),
                                            Text(
                                              '$completedTasks ${completedTasks == 1 ? 'tarea completada' : 'tareas completadas'}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12.0),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF08143C),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.hourglass_empty,
                                              size: 20.0,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4.0),
                                            if (pendingTasks > 0)
                                              Text(
                                                '$pendingTasks ${pendingTasks == 1 ? 'cliente' : 'clientes'} en espera',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.0),
                                              )
                                            else
                                              const Text(
                                                'DISPONIBLE',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.0,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const CupertinoActivityIndicator(
                                radius: 16,
                                color: Colors.green,
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Servicios ofrecidos:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Mostrar los servicios del proveedor
                          _buildSupplierServices(supplierData['uid']),
                          const SizedBox(height: 30),
                          _buildPublicationsCarousel(supplierData['uid']),
                          const SizedBox(height: 30),
                          _buildRatingsAndReviews(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Función para construir la sección de servicios del proveedor
  Widget _buildSupplierServices(String supplierUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.supplierId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }
        if (snapshot.hasError) {
          return const Text('Error al obtener los servicios');
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          List<dynamic> services = snapshot.data!['services'];

          return Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: services.map((serviceData) {
              String serviceId = serviceData['service'];
              return _buildServiceChip(serviceId);
            }).toList(),
          );
        } else {
          return const Text('El proveedor no tiene servicios registrados');
        }
      },
    );
  }

  // Función para construir cada chip de servicio
  Widget _buildServiceChip(String serviceId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator();
        }
        if (snapshot.hasError) {
          return const Text('Error al obtener el servicio');
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          String serviceName = snapshot.data!['serviceName'];
          return Chip(
            label: Text(serviceName),
            backgroundColor: Colors.blueGrey[700],
            labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildPublicationsCarousel(String supplierUid) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.supplierId)
          .collection('publications')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CupertinoActivityIndicator(
            radius: 20,
            color: Colors.green,
          ));
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(height: 0);
        }

        List<QueryDocumentSnapshot> publications = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Publicaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Botón para mostrar el BottomSheet con la lista de publicaciones
                IconButton(
                  onPressed: () {
                    _showPublicationsBottomSheet();
                  },
                  icon: const Icon(Icons.grid_view),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (publications.length == 1)
              _buildSinglePublication(publications.first)
            else
              _buildMultiplePublications(publications),
          ],
        );
      },
    );
  }

  Widget _buildSinglePublication(QueryDocumentSnapshot publication) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(
              imageUrl: publication['PostImageUrl'],
              isCoverImage: false,
            ),
          ),
        );
      },
      child: Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            publication['PostImageUrl'],
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplePublications(List<QueryDocumentSnapshot> publications) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 200,
        aspectRatio: 16 / 9,
        viewportFraction: 0.8,
        initialPage: 0,
        enableInfiniteScroll: publications.length > 1,
        reverse: false,
        autoPlay: publications.length > 1,
        autoPlayInterval: const Duration(seconds: 3),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        enlargeCenterPage: true,
        scrollDirection: Axis.horizontal,
      ),
      items: publications.map((publication) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePreviewScreen(
                      imageUrl: publication['PostImageUrl'],
                      isCoverImage: false,
                    ),
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    publication['PostImageUrl'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatingsAndReviews() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSupplierRatings(widget.supplierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CupertinoActivityIndicator(
            radius: 20,
            color: Colors.green,
          ));
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> ratingsData = snapshot.data!;
        double averageRating = ratingsData['averageRating'];
        int totalRatings = ratingsData['totalRatings'];
        Map<int, int> ratingCounts = ratingsData['ratingCounts'];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calificaciones y Opiniones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF08143C),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08143C),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '($totalRatings)',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (int i = 5; i >= 1; i--)
                _buildStarRating(i, ratingCounts[i] ?? 0, totalRatings),
              const SizedBox(height: 20),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('tasks')
                    .orderBy('end', descending: true)
                    .limit(10)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CupertinoActivityIndicator(
                      radius: 20,
                      color: Colors.green,
                    ));
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks =
                      snapshot.data!.docs;

                  return Column(
                    children: tasks
                        .where((task) =>
                            task.data()['supplierID'] == widget.supplierId &&
                            task.data()['clientEvaluation'] != null &&
                            task.data()['clientComment'] != null)
                        .map((task) => _buildClientReview(task))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              if (totalRatings > 0)
                Center(
                  child: TextButton(
                    onPressed: () {
                      _showFullReviewsBottomSheet();
                    },
                    child: const Text(
                      'Ver todas las opiniones',
                      style: TextStyle(
                        color: Color(0xFF08143C),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating(int stars, int count, int total) {
    double percentage = total > 0 ? (count / total) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars'),
          const SizedBox(width: 5),
          const Icon(Icons.star, size: 16, color: Colors.green),
          const SizedBox(width: 5),
          Expanded(
            child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 8,
                borderRadius: BorderRadius.circular(30)),
          ),
          const SizedBox(width: 5),
          Text('${percentage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildClientReview(QueryDocumentSnapshot<Map<String, dynamic>> task) {
    final clientID = task.data()['clientID'];
    final clientEvaluation = task.data()['clientEvaluation'];
    final clientComment = task.data()['clientComment'];
    final taskEndDate = task.data()['end'] as Timestamp?;
    final serviceName =
        task.data()['service'] ?? 'General'; // Obtener el nombre del servicio

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(clientID).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          );
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final clientData = snapshot.data!.data();
        final clientName = '${clientData?['name']} ${clientData?['lastName']}';
        final profileImageUrl = clientData?['profileImageUrl'];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImageUrl != null &&
                            profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : const AssetImage(
                                'assets/images/ProfilePhoto_predetermined.png')
                            as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          for (int i = 0; i < clientEvaluation; i++)
                            const Icon(Icons.star,
                                size: 16, color: Colors.green),
                          for (int i = 0; i < (5 - clientEvaluation); i++)
                            const Icon(Icons.star,
                                size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          if (taskEndDate != null)
                            Text(
                              DateFormat('dd/MM/yyyy')
                                  .format(taskEndDate.toDate()),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLabelColor(serviceName),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                clientComment,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  // Widget para mostrar la cantidad de seguidores de manera elegante
  Widget _buildFollowerCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.supplierId)
          .collection('followers')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoActivityIndicator();
        }
        if (snapshot.hasError) {
          return const Text('Error');
        }
        final followerCount = snapshot.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 12.0,
          ),
          width: 170,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people,
                size: 18.0,
                color: Colors.black,
              ),
              const SizedBox(width: 4.0),
              // Modificaciones para el tamaño del texto
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$followerCount ',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: 'seguidores',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height *
              0.80, // 80% de la altura de la pantalla
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Todas las opiniones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF08143C),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('tasks')
                    .orderBy('end', descending: true)
                    .where('supplierID', isEqualTo: widget.supplierId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CupertinoActivityIndicator(
                      radius: 20,
                      color: Colors.green,
                    ));
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks =
                      snapshot.data!.docs;

                  return Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        if (task.data()['clientEvaluation'] != null &&
                            task.data()['clientComment'] != null) {
                          return _buildClientReview(task);
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<int>> _getTaskCounts(String supplierID) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    int completedTasks = 0;
    int pendingTasks = 0;

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['supplierID'] == supplierID) {
        if (taskDoc.data()['state'] == 'Finalizada') {
          completedTasks++;
        } else if (taskDoc.data()['state'] != 'Finalizada' &&
            taskDoc.data()['state'] != 'Cancelada') {
          pendingTasks++;
        }
      }
    }

    return [completedTasks, pendingTasks];
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
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDelayTimer;

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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDelayTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchDelayTimer?.isActive ?? false) {
      _searchDelayTimer!.cancel();
    }
    _searchDelayTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar chats...',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {},
                )
              : const Text(
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
              icon: Icon(_isSearching ? Icons.close : Icons.search,
                  color: Colors.black),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        body: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          stream: getConversations(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Error al cargar conversaciones'));
            }

            if (snapshot.hasData) {
              final conversations = snapshot.data!;
              final filteredConversations = conversations.where((conversation) {
                final supplierName =
                    conversation.data()?['supplierName'] as String? ?? '';
                return supplierName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
              }).toList();

              return ListView.builder(
                itemCount: filteredConversations.length,
                itemBuilder: (context, index) {
                  final conversation = filteredConversations[index];
                  final clientID = conversation.data()?['clientID'];
                  final supplierID = conversation.data()?['supplierID'];
                  final supplierName = conversation.data()?['supplierName'];
                  final lastMessage = conversation.data()?['lastMessage'];
                  final lastMessageTimestamp = conversation
                      .data()?['lastMessageTimestamp'] as Timestamp?;
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
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                content: getSupplierProfileImage(supplierID),
                              );
                            },
                          );
                        },
                        child: getSupplierProfileImage(supplierID),
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
                              color:
                                  conversation.data()?['lastMessageIsRead'] ==
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
        ));
  }

  Widget getSupplierProfileImage(String? supplierID) {
    return FutureBuilder<String?>(
      future: getSupplierProfileImageUrl(supplierID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final profileImageUrl = snapshot.data;
          return CircleAvatar(
            radius: 25,
            backgroundImage: profileImageUrl != null
                ? CachedNetworkImageProvider(profileImageUrl) as ImageProvider
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
    );
  }

  Future<String?> getSupplierProfileImageUrl(String? supplierID) async {
    if (supplierID == null) {
      return null;
    }
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

      final storageRef = firebase_storage.FirebaseStorage.instance.ref().child(
          'chat_images/$_chatID/${DateTime.now().millisecondsSinceEpoch}');
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
      height:
          (decodedImage.height * 0.7).toInt(), // Reducir la altura en un 30%
    );

    final encodedImage =
        img.encodeJpg(compressedImage, quality: 70); // Reducir la calidad a 70
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

  void _showChatReportBottomSheet() {
    String selectedReason = '';
    String otherReason = '';
    bool isOtherSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Reportar chat',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        'Lenguaje inapropiado',
                        'Información personal',
                        'Acoso',
                        'Estafa',
                        'Imagenes indebidas',
                        'Genera desconfianza',
                        'Tiempo prolongado de espera',
                        'Información falsa',
                        'Malos hábitos',
                        'Poca experiencia laboral',
                        'Ventas ilícitas',
                        'Spam',
                        'Otro',
                      ].map((String reason) {
                        return ChoiceChip(
                          label: Text(
                            reason,
                            style: TextStyle(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          selectedColor: selectedReason == reason
                              ? const Color(0xFF08143C)
                              : null,
                          selected: selectedReason == reason,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedReason = selected ? reason : '';
                              isOtherSelected = reason == 'Otro';
                            });
                          },
                          // Add this to change checkmark color
                          selectedShadowColor: Colors.transparent,
                          disabledColor: Colors.transparent,
                          checkmarkColor: Colors.green,
                        );
                      }).toList(),
                    ),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        onChanged: (value) {
                          otherReason = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Especifique el motivo',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: 'Ingresa el motivo',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.blueGrey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                                const BorderSide(color: Color(0xFF08143c)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el motivo';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ca424),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () =>
                            _submitChatReport(selectedReason, otherReason),
                        child: const Text('Enviar reporte'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _submitChatReport(String selectedReason, String otherReason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado')),
      );
      return;
    }

    final reporterDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    if (reporterDoc.docs.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error: No se pudo obtener la información del usuario')),
      );
      return;
    }

    final reporterData = reporterDoc.docs.first.data();

    // Obtener el nombre y apellido del usuario reportado
    final reportedUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.supplierID)
        .get();

    if (reportedUserDoc.exists) {
      final reportedUserData = reportedUserDoc.data()!;
      final reportedUserName =
          '${reportedUserData['name']} ${reportedUserData['lastName']}';

      final reportData = {
        'timestamp': FieldValue.serverTimestamp(),
        'reportedUserName':
            reportedUserName, // Usar el nombre del usuario reportado
        'reportedUserId': widget.supplierID,
        'reason': selectedReason == 'Otro' ? otherReason : selectedReason,
        'category': 'Chat',
        'reporterName': '${reporterData['name']} ${reporterData['lastName']}',
        'reporterId': reporterDoc.docs.first.id,
        'chatId': _chatID,
      };

      // Generar el ID del documento
      final DateTime now = DateTime.now();
      final String documentId =
          '${widget.supplierID}_${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}';

      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(documentId)
            .set(reportData);
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado')),
        );
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el reporte')),
        );
      }
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: No se pudo obtener la información del usuario reportado')),
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
            : InkWell(
                // Se añade InkWell aquí
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileViewScreen(supplierId: widget.supplierID),
                    ),
                  );
                },
                child: Row(
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
                value: 'Reportar chat',
                child: Text('Reportar chat'),
              ),
            ],
            onSelected: (value) {
              if (value == 'Ver perfil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileViewScreen(supplierId: widget.supplierID),
                  ),
                );
              } else if (value == 'Multimedia') {
                _showMultimediaScreen();
              } else if (value == 'Reportar chat') {
                _showChatReportBottomSheet();
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                                      hintStyle:
                                          TextStyle(color: Colors.blueGrey),
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
                              padding:
                                  const EdgeInsets.only(top: 8.0, left: 16.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
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
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (_selectedImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                              20), // Define el radio de los bordes redondeados
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
                      final errorMessage = _containsRestrictedContent(
                          _imageMessageController.text.trim());
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

          return const Center(
              child: CupertinoActivityIndicator(
            radius: 16,
            color: Colors.green,
          ));
        },
      ),
    );
  }
}
