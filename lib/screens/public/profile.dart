import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import '../intro_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:one_context/one_context.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  String _userLastName = '';
  String _userID = '';
  String _userBio = '';
  String _profileImageUrl = '';
  String _coverImageUrl = '';
  String _userAssessment = '0';
  String _userAssessmentCount = '0';

  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _userStream;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenForUserUpdates();
  }

  @override
  void dispose() {
    _userStream.cancel();
    super.dispose();
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
        List<dynamic> averageSupplierEvaluation =
            await getAverageSupplierEvaluation(combinedId);

        setState(() {
          _userName = userDoc.data()!['name'];
          _userLastName = userDoc.data()!['lastName'];
          _userBio = userDoc.data()!['bio'] ?? '';
          _profileImageUrl = userDoc.data()!['profileImageUrl'] ?? '';
          _coverImageUrl = userDoc.data()!['coverImageUrl'] ?? '';
          _userAssessment = averageSupplierEvaluation[0].toString();
          _userAssessmentCount = averageSupplierEvaluation[1].toString();
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

  Future _updateProfileData({
    String? updatedUserName,
    String? updatedUserLastName,
    String? updatedUserBio,
    String? updatedProfileImageUrl,
    String? updatedCoverImageUrl,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .update({
        'name': updatedUserName ?? _userName,
        'lastName': updatedUserLastName ?? _userLastName,
        'bio': updatedUserBio ?? _userBio,
        'profileImageUrl': updatedProfileImageUrl ?? _profileImageUrl,
        'coverImageUrl': updatedCoverImageUrl ?? _coverImageUrl,
      });
    }
  }

  Future _selectImageFromGallery(bool isCoverImage) async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);

  if (image != null) {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: isCoverImage 
          ? const CropAspectRatio(ratioX: 1200, ratioY: 630)
          : const CropAspectRatio(ratioX: 400, ratioY: 400),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: isCoverImage ? 'Ajustar foto de portada' : 'Ajustar foto de perfil',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          backgroundColor: Colors.white,
          statusBarColor: Colors.white,
          activeControlsWidgetColor: Colors.green,
          cropFrameColor: Colors.green,
          cropGridColor: Colors.grey[300],
          hideBottomControls: false,
          initAspectRatio: isCoverImage ? CropAspectRatioPreset.ratio16x9 : CropAspectRatioPreset.ratio4x3,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: isCoverImage ? 'Ajustar foto de portada' : 'Ajustar foto de perfil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      if (isCoverImage) {
        _uploadCoverImageToFirebase(croppedFile.path);
      } else {
        _uploadProfileImageToFirebase(croppedFile.path);
      }
    }
  }
}

  // Método para comprimir y redimensionar la imagen
Future<File> _compressAndResizeImage(File imageFile, {int maxWidth = 800, int maxHeight = 600}) async {
  final img.Image? image = img.decodeImage(await imageFile.readAsBytes());

  if (image == null) {
    throw Exception("No se pudo decodificar la imagen");
  }

  // Redimensionar la imagen
  img.Image resizedImage = img.copyResize(
    image,
    width: maxWidth,
    height: maxHeight,
    interpolation: img.Interpolation.linear
  );

  // Comprimir la imagen redimensionada a un 85% de calidad
  final compressedImage = img.encodeJpg(resizedImage, quality: 85);

  final compressedFile = File(imageFile.path)
    ..writeAsBytesSync(compressedImage);

  return compressedFile;
}

Future _uploadProfileImageToFirebase(String imagePath) async {
  String fileName = DateTime.now().millisecondsSinceEpoch.toString();
  Reference storageReference =
      FirebaseStorage.instance.ref().child('profileImages/$fileName');

  try {
    // Eliminar la imagen de perfil existente
    if (_profileImageUrl.isNotEmpty) {
      await FirebaseStorage.instance.refFromURL(_profileImageUrl).delete();
    }

    // Comprimir y redimensionar la imagen antes de subirla
    File compressedFile = await _compressAndResizeImage(
      File(imagePath),
      maxWidth: 400,
      maxHeight: 500
    );

    // Subir la imagen comprimida y redimensionada
    UploadTask uploadTask = storageReference.putFile(compressedFile);

    await uploadTask.whenComplete(() async {
      String downloadUrl = await storageReference.getDownloadURL();
      setState(() {
        _profileImageUrl = downloadUrl;
      });
      _updateProfileData(updatedProfileImageUrl: downloadUrl);
    });
  } catch (e) {
    OneContext().showSnackBar(
      builder: (_) => SnackBar(
        content: Text('Error al subir la imagen: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future _uploadCoverImageToFirebase(String imagePath) async {
  String fileName = DateTime.now().millisecondsSinceEpoch.toString();
  Reference storageReference =
      FirebaseStorage.instance.ref().child('coverImages/$fileName');

  try {
    // Eliminar la imagen de portada existente
    if (_coverImageUrl.isNotEmpty) {
      await FirebaseStorage.instance.refFromURL(_coverImageUrl).delete();
    }

    // Comprimir y redimensionar la imagen antes de subirla
    File compressedFile = await _compressAndResizeImage(
      File(imagePath),
      maxWidth: 1200,
      maxHeight: 630
    );

    // Subir la imagen comprimida y redimensionada
    UploadTask uploadTask = storageReference.putFile(compressedFile);
    await uploadTask.whenComplete(() async {
      String downloadUrl = await storageReference.getDownloadURL();
      setState(() {
        _coverImageUrl = downloadUrl;
      });
      _updateProfileData(updatedCoverImageUrl: downloadUrl);
    });
  } catch (e) {
    OneContext().showSnackBar(
      builder: (_) => SnackBar(
        content: Text('Error al subir la imagen: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _showEditProfileScreen() {
    OneContext().push(
      MaterialPageRoute(
        builder: (context) => _EditProfileScreen(
          userBio: _userBio,
          profileImageUrl: _profileImageUrl,
          coverImageUrl: _coverImageUrl,
          onUpdateProfile: _updateProfileData,
          onSelectImage: _selectImageFromGallery,
        ),
      ),
    );
  }

  void _showSecurityAndPrivacyScreen() {
    OneContext().push(
      MaterialPageRoute(
        builder: (context) => const SecurityAndPrivacyScreen(),
      ),
    );
  }

  void _showAccountScreen() {
    OneContext().push(
      MaterialPageRoute(
        builder: (context) => const AccountScreen(),
      ),
    );
  }

  void _showHelpScreen() {
    OneContext().push(
      MaterialPageRoute(
        builder: (context) => const HelpScreen(),
      ),
    );
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    OneContext().pushReplacement(
      MaterialPageRoute(builder: (context) => const IntroScreen()),
    );
  }

  void _listenForUserUpdates() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          setState(() {
            _userName = snapshot.data()!['name'];
            _userLastName = snapshot.data()!['lastName'];
            _userID = combinedId;
            _userBio = snapshot.data()!['bio'] ?? '';
            _profileImageUrl = snapshot.data()!['profileImageUrl'] ?? '';
            _coverImageUrl = snapshot.data()!['coverImageUrl'] ?? '';
          });
        }
      });
    }
  }

  Future<List<dynamic>> getAverageSupplierEvaluation(String combinedId) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    double totalEvaluation = 0;
    int evaluationCount = 0;

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['clientID'] == combinedId &&
          taskDoc.data().containsKey('supplierEvaluation')) {
        totalEvaluation +=
            double.tryParse(taskDoc.data()['supplierEvaluation'].toString()) ??
                0.0;
        evaluationCount++;
      }
    }

    if (evaluationCount == 0) {
      return ['0', 0];
    } else {
      double averageEvaluation = totalEvaluation / evaluationCount;
      return [averageEvaluation.toStringAsFixed(1), evaluationCount];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Portada azul oscura, CircleAvatar y botón "Editar perfil"
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    if (_coverImageUrl.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImagePreviewScreen(
                            imageUrl: _coverImageUrl,
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
                    child: _coverImageUrl.isEmpty
                        ? Container(
                            height: 190,
                            color: const Color(0xFF08143c),
                          )
                        : Container(
                            height: 190,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(_coverImageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 125,
                  left: 20,
                  child: GestureDetector(
                    onTap: () {
                      if (_profileImageUrl.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImagePreviewScreen(
                              imageUrl: _profileImageUrl,
                              isCoverImage: false,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4.0,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : const AssetImage(
                                    'assets/images/ProfilePhoto_predetermined.png')
                                as ImageProvider,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 10.0),
              child: Align(
                alignment: Alignment.topRight,
                child: ElevatedButton(
                  onPressed: _showEditProfileScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF08143c),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: const BorderSide(color: Color(0xFF08143c)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 7.0),
                  ),
                  child: const Text(
                    'Personalizar',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Contenido de la pantalla (nombre, biografía, etc.)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y apellido
                  Text(
                    '$_userName $_userLastName',
                    style: const TextStyle(
                      fontSize: 25.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08143c),
                    ),
                  ),

                  Text(
                    'ID: $_userID',
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(176, 190, 197, 1),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Biografía del usuario
                  Text(
                    _userBio,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromRGBO(38, 50, 56, 1),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Puntuación del usuario
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF08143c),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize
                          .min, // Agrega esto para que el Row tome el mínimo espacio posible.
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFD700),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _userAssessment,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          // ignore: unrelated_type_equality_checks
                          '($_userAssessmentCount ${_userAssessmentCount == 1 ? 'opinión' : 'opiniones'})',
                          style: const TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.normal,
                            color: Colors
                                .white, // Puedes cambiar el color del texto si lo deseas.
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Lista de opciones del menú
            _buildMenuItem(
              icon: Icons.security,
              title: 'Seguridad y privacidad',
              onTap: _showSecurityAndPrivacyScreen,
            ),
            _buildMenuItem(
              icon: Icons.account_circle,
              title: 'Cuenta',
              onTap: _showAccountScreen,
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Ayuda',
              onTap: _showHelpScreen,
            ),
            const SizedBox(height: 30.0),

            // Botón "Cerrar sesión"
            Center(
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30.0, vertical: 15.0),
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontSize: 16.0, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Función para construir cada elemento del menú
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 25.0), // Ajusta el valor según lo que necesites
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF08143c)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            color: Color(0xFF08143c),
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Color(0xFF08143c)),
        onTap: onTap,
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  final String userBio;
  final String profileImageUrl;
  final String coverImageUrl;
  final Function onUpdateProfile;
  final Function onSelectImage;

  const _EditProfileScreen({
    required this.userBio,
    required this.profileImageUrl,
    required this.coverImageUrl,
    required this.onUpdateProfile,
    required this.onSelectImage,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bioController;
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _userStream;
  String _currentProfileImageUrl = '';
  String _currentCoverImageUrl = '';
  bool _isBioFocused = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.userBio);
    _currentProfileImageUrl = widget.profileImageUrl;
    _currentCoverImageUrl = widget.coverImageUrl;
    _listenForUserUpdates();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _userStream.cancel();
    super.dispose();
  }

  void _listenForUserUpdates() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          setState(() {
            _bioController.text = snapshot.data()!['bio'] ?? '';
            _currentProfileImageUrl =
                snapshot.data()!['profileImageUrl'] ?? '';
            _currentCoverImageUrl = snapshot.data()!['coverImageUrl'] ?? '';
          });
        }
      });
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

  Future<void> _showProfileImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Actualizar foto de perfil'),
              onTap: () async {
                Navigator.pop(context);
                await widget.onSelectImage(false);
              },
            ),
            if (_currentProfileImageUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar foto de perfil'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteProfileImage();
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCoverImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Actualizar foto de portada'),
              onTap: () async {
                Navigator.pop(context);
                await widget.onSelectImage(true);
              },
            ),
            if (_currentCoverImageUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Eliminar foto de portada'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteCoverImage();
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProfileImage() async {
    try {
      if (_currentProfileImageUrl.isNotEmpty) {
        await FirebaseStorage.instance
            .refFromURL(_currentProfileImageUrl)
            .delete();
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String combinedId = await _getCombinedIdFromFirestore(user.uid);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .update({
          'profileImageUrl': '',
        });
      }

      setState(() {
        _currentProfileImageUrl = '';
      });

      await widget.onUpdateProfile(updatedUserBio: _bioController.text);
    } catch (e) {
      if (kDebugMode) {
        print("Error al eliminar la imagen de perfil: $e");
      }
    }
  }

  Future<void> _deleteCoverImage() async {
    try {
      if (_currentCoverImageUrl.isNotEmpty) {
        await FirebaseStorage.instance
            .refFromURL(_currentCoverImageUrl)
            .delete();
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String combinedId = await _getCombinedIdFromFirestore(user.uid);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .update({
          'coverImageUrl': '',
        });
      }

      setState(() {
        _currentCoverImageUrl = '';
      });

      await widget.onUpdateProfile(updatedUserBio: _bioController.text);
    } catch (e) {
      if (kDebugMode) {
        print("Error al eliminar la imagen de portada: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF08143c),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _showCoverImageOptions,
                      child: Container(
                        width: double.infinity,
                        height: 150.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: const Color(0xFF08143c),
                            width: 1.0,
                          ),
                          image: _currentCoverImageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_currentCoverImageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _currentCoverImageUrl.isEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF08143c),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 68.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Agregar portada',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: 20,
                      child: GestureDetector(
                        onTap: _showProfileImageOptions,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4.0,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: _currentProfileImageUrl.isNotEmpty
                                ? NetworkImage(_currentProfileImageUrl)
                                : const AssetImage(
                                        'assets/images/ProfilePhoto_predetermined.png')
                                    as ImageProvider,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30.0),
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isBioFocused = hasFocus;
                    });
                  },
                  child: TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: 'Biografía',
                      labelStyle: const TextStyle(
                        color: Color.fromRGBO(13, 71, 161, 1),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: const BorderSide(color: Color(0xFF08143c)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: const BorderSide(color: Color(0xFF1ca424)),
                      ),
                    ),
                    maxLines: _isBioFocused ? 3 : 1,
                    maxLength: 100,
                    validator: (value) {
                      if (value != null && value.length > 100) {
                        return 'La biografía debe tener un máximo de 100 caracteres';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30.0),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onUpdateProfile(
                        updatedUserBio: _bioController.text,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ca424),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 15.0),
                  ),
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.white,
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


class SecurityAndPrivacyScreen extends StatelessWidget {
  const SecurityAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => OneContext().pop(),
        ),
        title: const Text(
          'Seguridad y Privacidad',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF08143c),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          ListTile(
            leading: const Icon(Icons.lock, color: Color(0xFF08143c)),
            title: const Text('Contraseña'),
            onTap: () {
              OneContext().push(
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: Color(0xFF08143c)),
            title: const Text('Clave de pago'),
            onTap: () {
              OneContext().push(
                MaterialPageRoute(
                  builder: (context) => const ChangePaymentKeyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Color(0xFF08143c)),
            title: const Text('Usuarios bloqueados'),
            onTap: () {
              OneContext().push(
                MaterialPageRoute(
                  builder: (context) => const BlockedUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  // ignore: unused_element
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => ChangePasswordScreenState();
}

class ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future _updatePassword() async {
    if (_formKey.currentState!.validate()) {
      String currentPassword = _currentPasswordController.text.trim();
      String newPassword = _newPasswordController.text.trim();
      // ignore: unused_local_variable
      String confirmPassword = _confirmPasswordController.text.trim();

      // Verifica que la contraseña actual sea correcta
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Verifica la contraseña actual
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: user.email!,
              password: currentPassword,
            ),
          );
        }

        // Actualiza la contraseña en Firebase Auth
        await user!.updatePassword(newPassword);

        // Actualiza la contraseña en Firestore
        String combinedId = await _getCombinedIdFromFirestore(user.uid);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(combinedId)
            .update({'password': newPassword});

        // La contraseña se actualizó correctamente
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Contraseña actualizada exitosamente!.',
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

        // Limpia los campos de texto
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } on FirebaseAuthException {
        // La contraseña actual es incorrecta
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'La contraseña actual es incorrecta.',
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
  }

  // Función para obtener el ID combinado de Firestore
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
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        title: const Text(
          'Cambiar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide:  const BorderSide(color: Color(0xFF08143c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(color: Color(0xFF1ca424)),
                    ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu contraseña actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide:  const BorderSide(color: Color(0xFF08143c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(color: Color(0xFF1ca424)),
                    ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu nueva contraseña';
                  }
                  if (value.length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmación de contraseña',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide:  const BorderSide(color: Color(0xFF08143c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(color: Color(0xFF1ca424)),
                    ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirma tu nueva contraseña';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.update, color: Colors.white),
                    SizedBox(width: 10.0),
                    Text(
                      'Actualizar contraseña',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangePaymentKeyScreen extends StatefulWidget {
  const ChangePaymentKeyScreen({super.key});

  @override
  State<ChangePaymentKeyScreen> createState() => _ChangePaymentKeyScreenState();
}

class _ChangePaymentKeyScreenState extends State<ChangePaymentKeyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _currentPinController;
  late TextEditingController _newPinController;
  late TextEditingController _confirmPinController;
  bool _hasPinCreated = false;

  @override
  void initState() {
    super.initState();
    _currentPinController = TextEditingController();
    _newPinController = TextEditingController();
    _confirmPinController = TextEditingController();
    _checkExistingPin();
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(combinedId)
          .get();

      setState(() {
        _hasPinCreated = doc.data() != null &&
            (doc.data() as Map<String, dynamic>).containsKey('pin');
      });
    }
  }

  Future<void> _updatePin() async {
    if (_formKey.currentState!.validate()) {
      String newPin = _newPinController.text.trim();

      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String combinedId = await _getCombinedIdFromFirestore(user.uid);
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(combinedId)
              .get();

          if (_hasPinCreated) {
            String currentPin = _currentPinController.text.trim();
            if (doc.data() != null &&
                (doc.data() as Map<String, dynamic>)['pin'] != currentPin) {
              _showSnackBar('El PIN actual es incorrecto.', Colors.red);
              return;
            }
          }

          // Actualiza el PIN en Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(combinedId)
              .update({'pin': newPin});

          _showSnackBar('¡PIN actualizado exitosamente!', Colors.green);

          // Limpia los campos de texto
          _currentPinController.clear();
          _newPinController.clear();
          _confirmPinController.clear();
        }
      } catch (e) {
        _showSnackBar('Error al actualizar el PIN.', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Clave de pago',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_hasPinCreated)
                TextFormField(
                  controller: _currentPinController,
                  decoration: InputDecoration(
                    labelText: 'PIN actual',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(color: Color(0xFF08143c)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.0),
                      borderSide: const BorderSide(color: Color(0xFF1ca424)),
                    ),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, ingresa tu PIN actual';
                    }
                    return null;
                  },
                  maxLength: 4,
                ),
              if (_hasPinCreated) const SizedBox(height: 16.0),
              TextFormField(
                controller: _newPinController,
                decoration: InputDecoration(
                  labelText: 'Nuevo PIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFF1ca424)),
                  ),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu nuevo PIN';
                  }
                  if (value.length != 4) {
                    return 'El PIN debe tener 4 dígitos';
                  }
                  return null;
                },
                maxLength: 4,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _confirmPinController,
                decoration: InputDecoration(
                  labelText: 'Confirmar nuevo PIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: const BorderSide(color: Color(0xFF1ca424)),
                  ),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, confirma tu nuevo PIN';
                  }
                  if (value != _newPinController.text) {
                    return 'Los PINs no coinciden';
                  }
                  return null;
                },
                maxLengthEnforcement: 4,
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _updatePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.update, color: Colors.white),
                    SizedBox(width: 10.0),
                    Text(
                      'Actualizar PIN',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios Bloqueados'),
      ),
      body: const Center(
        child: Text('Lista de usuarios bloqueados'),
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _getUserData();
  }

  Future<Map<String, dynamic>> _getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String combinedId = await _getCombinedIdFromFirestore(user.uid);
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(combinedId)
          .get();

      if (userDoc.exists) {
        return userDoc.data()!;
      }
    }
    throw Exception('No se pudo obtener los datos del usuario');
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => OneContext().pop(),
        ),
        title: const Text(
          'Cuenta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF08143c),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final userData = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de la cuenta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08143c),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('Nombre y apellido'),
                    subtitle: Text('${userData['name']} ${userData['lastName']}'),
                  ),
                  ListTile(
                    title: const Text('Género'),
                    subtitle: Text(userData['gender'] ?? 'No especificado'),
                  ),
                  ListTile(
                    title: const Text('Correo electrónico'),
                    subtitle: Text(userData['email']),
                  ),
                  ListTile(
                    title: const Text('Número telefónico'),
                    subtitle: Text(userData['phone'] ?? 'No especificado'),
                  ),
                  ListTile(
                    title: const Text('Fecha de nacimiento'),
                    subtitle: Text(_formatDate(userData['birthDate'])),
                  ),
                  ListTile(
                    title: const Text('Apertura de la cuenta'),
                    subtitle: Text(_formatDate(userData['registrationDate'])),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Lógica para eliminar la cuenta
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30.0, vertical: 15.0),
                      ),
                      child: const Text(
                        'Eliminar cuenta',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text('No se encontraron datos'));
          }
        },
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => OneContext().pop(),
        ),
        title: const Text(
          'Ayuda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF08143c),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpSection(
              context,
              'Preguntas frecuentes',
              Icons.question_answer,
              const FrequentQuestionsScreen(),
            ),
            _buildHelpSection(
              context,
              'Términos y condiciones',
              Icons.description,
              const TermsAndConditionsScreen(),
            ),
            _buildHelpSection(
              context,
              'Acerca de la app',
              Icons.info,
              const AboutAppScreen(),
            ),
            const SizedBox(height: 30),
            Card(
              color: Colors.blueGrey[50],
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Soporte al usuario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF08143c),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSupportOption(
                      context,
                      'Mensajería interna',
                      Icons.message,
                      const InternalMessagingScreen(),
                    ),
                    _buildSupportOption(
                      context,
                      'Correo electrónico',
                      Icons.email,
                      const EmailSupportScreen(),
                    ),
                    _buildSupportOption(
                      context,
                      'Vía WhatsApp',
                      Icons.phone_iphone_rounded,
                      () async {
                        final Uri whatsappUrl = Uri.parse(
                            'https://wa.me/584245069119?text=Hola%20Soporte%2C%20necesito%20ayuda%20con...');
                        if (await canLaunchUrl(whatsappUrl)) {
                          await launchUrl(whatsappUrl);
                        } else {
                          OneContext().showSnackBar(
                            builder: (_) => const SnackBar(
                              content: Text('No se pudo abrir WhatsApp'),
                            ),
                          );
                        }
                      },
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

  Widget _buildHelpSection(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF08143c)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF08143c)),
      onTap: () {
        OneContext().push(
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }

  Widget _buildSupportOption(
    BuildContext context,
    String title,
    IconData icon,
    dynamic onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1ca424)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF1ca424)),
      onTap: onTap is Function
          ? () => onTap() // Llamamos a la función si es una función
          : (onTap is Widget
              ? () => OneContext().push(
                    MaterialPageRoute(builder: (context) => onTap),
                  )
              : null), // Si no es ni función ni Widget, asignamos null
    );
  }
}

class FrequentQuestionsScreen extends StatelessWidget {
  const FrequentQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preguntas frecuentes')),
      body: const Center(child: Text('Pantalla de Preguntas frecuentes')),
    );
  }
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de la app')),
      body: const Center(child: Text('Información sobre la aplicación')),
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y condiciones')),
      body: const Center(child: Text('Términos y condiciones de uso')),
    );
  }
}

class InternalMessagingScreen extends StatelessWidget {
  const InternalMessagingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajería interna')),
      body: const Center(child: Text('Sistema de mensajería interna')),
    );
  }
}

class EmailSupportScreen extends StatelessWidget {
  const EmailSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soporte por correo')),
      body: const Center(child: Text('Formulario de contacto por correo')),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final bool isCoverImage;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrl,
    this.isCoverImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(); // Regresa a la pantalla anterior
          },
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          backgroundDecoration: const BoxDecoration(
            color: Colors.black,
          ),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      ),
    );
  }
}
