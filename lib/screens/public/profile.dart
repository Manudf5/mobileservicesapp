import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import './../intro_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:one_context/one_context.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mobileservicesapp/screens/public/homepage.dart';

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
  bool _verified = false;
  bool _isRegularUser = false;

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
          _userID = combinedId; // Asegúrate de que esta línea esté presente
          _userBio = userDoc.data()!['bio'] ?? '';
          _profileImageUrl = userDoc.data()!['profileImageUrl'] ?? '';
          _coverImageUrl = userDoc.data()!['coverImageUrl'] ?? '';
          _userAssessment = averageSupplierEvaluation[0].toString();
          _userAssessmentCount = averageSupplierEvaluation[1].toString();
          _verified = userDoc.data()!['verified'] ??
              false; // Obtiene el valor de verified
          _isRegularUser = userDoc.data()!['role'] == 0;
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
            toolbarTitle: isCoverImage
                ? 'Ajustar foto de portada'
                : 'Ajustar foto de perfil',
            toolbarColor: Colors.white,
            toolbarWidgetColor: Colors.black,
            backgroundColor: Colors.white,
            statusBarColor: Colors.white,
            activeControlsWidgetColor: Colors.green,
            cropFrameColor: Colors.green,
            cropGridColor: Colors.grey[300],
            hideBottomControls: false,
            initAspectRatio: isCoverImage
                ? CropAspectRatioPreset.ratio16x9
                : CropAspectRatioPreset.ratio4x3,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: isCoverImage
                ? 'Ajustar foto de portada'
                : 'Ajustar foto de perfil',
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
  Future<File> _compressAndResizeImage(File imageFile,
      {int maxWidth = 800, int maxHeight = 600}) async {
    final img.Image? image = img.decodeImage(await imageFile.readAsBytes());

    if (image == null) {
      throw Exception("No se pudo decodificar la imagen");
    }

    // Redimensionar la imagen
    img.Image resizedImage = img.copyResize(image,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear);

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
      File compressedFile = await _compressAndResizeImage(File(imagePath),
          maxWidth: 400, maxHeight: 400);

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
      File compressedFile = await _compressAndResizeImage(File(imagePath),
          maxWidth: 1200, maxHeight: 630);

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

  Future<List<Map<String, dynamic>>> getDetailedEvaluations(
      String combinedId) async {
    QuerySnapshot<Map<String, dynamic>> tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();

    List<Map<String, dynamic>> evaluations = [];

    for (var taskDoc in tasksSnapshot.docs) {
      if (taskDoc.data()['clientID'] == combinedId &&
          taskDoc.data().containsKey('supplierEvaluation')) {
        evaluations.add({
          'taskId': taskDoc.id,
          'evaluation': taskDoc.data()['supplierEvaluation'],
          'comment': taskDoc.data()['supplierComment'] ?? 'Sin comentario'
        });
      }
    }

    return evaluations;
  }

  void _showEvaluationsModal(BuildContext context) async {
    List<Map<String, dynamic>> evaluations =
        await getDetailedEvaluations(_userID);

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 5,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const Text(
                'Opiniones detalladas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF08143c),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: evaluations.length,
                  itemBuilder: (context, index) {
                    return _buildEvaluationCard(evaluations[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    return Card(
      color: Colors.blueGrey[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // Agrega un borde al Card con un ancho de 1
        side: const BorderSide(color: Colors.blueGrey, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TaskID: ${evaluation['taskId']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.yellow, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${evaluation['evaluation']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              evaluation['comment'],
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
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
                  ).animate().fadeIn().slideY(),
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
                    ).animate().fade().scale(),
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
                  // Nombre, apellido y verificado true o false.
                  Row(
                    children: [
                      Text(
                        '$_userName $_userLastName',
                        style: const TextStyle(
                          fontSize: 25.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF08143c),
                        ),
                      ),
                      const SizedBox(
                          width: 5), // Espacio entre el nombre y el icono
                      if (_verified == true) // Verifica si verified es true
                        const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 22,
                        ),
                    ],
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
                  GestureDetector(
                    onTap: () {
                      _showEvaluationsModal(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF08143c),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
            const SizedBox(height: 0.0),

            if (_isRegularUser)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: GestureDetector(
                  onTap: () async {
                    // Obtener el combinedId antes de navegar
                    String combinedId = await _getCombinedIdFromFirestore(
                        FirebaseAuth.instance.currentUser!.uid);

                    // Navegar a una nueva pantalla en blanco
                    Navigator.push(
                      // ignore: use_build_context_synchronously
                      context,
                      MaterialPageRoute(
                          builder: (context) => SuppliersPostulationFormScreen(
                              combinedId: combinedId)),
                    );
                  },
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.greenAccent[700]!,
                            Colors.green[900]!
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.rocket_launch,
                                    color: Colors.white, size: 40),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '¡Nuevo!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              '¡Conviértete en un agente MSA!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Únete a nuestra red de expertos y comienza a ganar dinero haciendo lo que amas.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Text(
                                'Postúlate Ahora',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideY(),
              ),
            const SizedBox(height: 5.0),
            // Botón "Cerrar sesión"
            Center(
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15.0, vertical: 7.0),
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(fontSize: 16.0, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30.0),
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
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF08143c)),
        onTap: onTap,
      ),
    ).animate().fadeIn().slideX();
  }
}

class SuppliersPostulationFormScreen extends StatefulWidget {
  final String combinedId;

  const SuppliersPostulationFormScreen({super.key, required this.combinedId});

  @override
  // ignore: library_private_types_in_public_api
  _SuppliersPostulationFormScreenState createState() =>
      _SuppliersPostulationFormScreenState();
}

class _SuppliersPostulationFormScreenState
    extends State<SuppliersPostulationFormScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _formKey = GlobalKey<FormState>();

  // Variables para almacenar los datos del formulario
  List<String> selectedServices = [];
  List<Map<String, dynamic>> servicesData = [];
  List<String> selectedAdditionalPaymentMethods = [];
  List<String> selectedDays = [];
  List<String> selectedTimesOfDay = [];
  List<Map<String, String>> jobReferences = [];
  List<Map<String, dynamic>> _allServicesData = [];
  List<Map<String, dynamic>> _filteredServicesData = [];
  bool _isLoadingServices = true;
  String _searchQuery = '';
  bool nationalTasks = false;
  bool ownVehicle = false;
  File? rifImage;
  File? cvFile;
  String healthInfo = '';
  double selectedTimeRange = 12.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoadingServices = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('services')
          .orderBy('serviceName')
          .get();

      setState(() {
        _allServicesData = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'serviceName': doc['serviceName'],
                  'imageUrl': doc['imageUrl'],
                })
            .toList();
        _filteredServicesData = List.from(_allServicesData);
        _isLoadingServices = false;
      });
    } catch (e) {
      // Manejar el error
      setState(() {
        _isLoadingServices = false;
      });
    }
  }

  void _filterServices(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredServicesData = _allServicesData
          .where((service) =>
              service['serviceName'].toLowerCase().contains(_searchQuery))
          .toList();
    });
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue[50]!],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    //physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildFirstPage(),
                      _buildSecondPage(),
                      _buildThirdPage(),
                      _buildFourthPage(),
                      _buildFifthPage(), // Nueva página de referencias laborales
                      _buildSixthPage(),
                    ],
                  ),
                ),
                _buildPageIndicator(),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Postulación MSA',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 40), // Para balance
        ],
      ),
    );
  }

  Widget _buildFirstPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/MSA_LogoTemporal.png',
            height: 120,
          ),
          const SizedBox(height: 30),
          Text(
            '¡Conviértete en agente!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildRequirementsList(),
          const SizedBox(height: 30),
          Card(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 40, color: Colors.amber),
                  const SizedBox(height: 10),
                  Text(
                    '¡Únete a nuestra red de profesionales y expande tus oportunidades!',
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsList() {
    final requirements = [
      'RIF vigente',
      'Pago móvil bancario habilitado',
      'Compromiso con la calidad de servicio',
      'Foto de perfil y de portada visibles',
      'Facilidad para movilizarse por la ciudad o en el territorio nacional',
    ];

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requisitos:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 10),
            ...requirements.map((req) => _buildRequirementItem(req)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Seleccione sus servicios',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        _buildSearchBar(),
        Expanded(
          child: _isLoadingServices
              ? const Center(child: CircularProgressIndicator())
              : _buildServiceGrid(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: _filterServices,
        decoration: InputDecoration(
          hintText: 'Buscar servicios...',
          prefixIcon: const Icon(Icons.search, color: Colors.blue),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.blue.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16/13,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredServicesData.length,
      itemBuilder: (context, index) {
        final service = _filteredServicesData[index];
        return _buildServiceItem(service);
      },
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> service) {
    final serviceId = service['id'];
    final isSelected = selectedServices.contains(serviceId);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedServices.remove(serviceId);
          } else {
            selectedServices.add(serviceId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: service['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      service['serviceName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue[800] : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.blue : Colors.grey.shade200,
                    ),
                    child: Center(
                      child: Icon(
                        isSelected ? Icons.check : Icons.add,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
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

  Widget _buildThirdPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configura tu disponibilidad',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 20),
          _buildDaysSelection(),
          const SizedBox(height: 20),
          _buildTimesOfDaySelection(),
          const SizedBox(height: 20),
          _buildNationalTasksSelection(),
          const SizedBox(height: 10),
          _buildOwnVehicleSelection(),
        ],
      ),
    );
  }

  Widget _buildDaysSelection() {
  final days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Días de trabajo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.map((day) => _buildDayCircle(day)).toList(),
      ),
    ],
  );
}

Widget _buildDayCircle(String day) {
  final isSelected = selectedDays.contains(day);
  return GestureDetector(
    onTap: () => setState(() {
      if (isSelected) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? Colors.blue : Colors.grey[200],
      ),
      child: Center(
        child: Text(day, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
      ),
    ),
  );
}

Widget _buildTimesOfDaySelection() {
  final timeOptions = [
    {'name': 'Madrugada', 'icon': Icons.nightlight_round},
    {'name': 'Mañana', 'icon': Icons.wb_sunny},
    {'name': 'Tarde', 'icon': Icons.wb_twighlight},
    {'name': 'Noche', 'icon': Icons.nights_stay},
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Momentos del día', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        childAspectRatio: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        children: timeOptions.map((option) => _buildTimeOption(option)).toList(),
      ),
    ],
  );
}

Widget _buildTimeOption(Map<String, dynamic> option) {
  final isSelected = selectedTimesOfDay.contains(option['name']);
  return InkWell(
    onTap: () {
      setState(() {
        if (isSelected) {
          selectedTimesOfDay.remove(option['name']);
        } else {
          selectedTimesOfDay.add(option['name']);
        }
      });
    },
    child: Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(option['icon'], color: isSelected ? Colors.blue : Colors.grey),
          const SizedBox(width: 8),
          Text(option['name'], style: TextStyle(color: isSelected ? Colors.blue : Colors.grey)),
        ],
      ),
    ),
  );
}

Widget _buildNationalTasksSelection() {
  return Row(
    children: [
      const Icon(Icons.public, color: Colors.blue),
      const SizedBox(width: 10),
      const Text('Disponibilidad nacional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Spacer(),
      Switch(
        value: nationalTasks,
        onChanged: (value) => setState(() => nationalTasks = value),
        activeColor: Colors.blue,
      ),
    ],
  );
}

Widget _buildOwnVehicleSelection() {
  return Row(
    children: [
      const Icon(Icons.car_rental_rounded, color: Colors.blue),
      const SizedBox(width: 10),
      const Text('Vehículo personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Spacer(),
      Switch(
        value: ownVehicle,
        onChanged: (value) => setState(() => ownVehicle = value),
        activeColor: Colors.blue,
      ),
    ],
  );
}

  Widget _buildFourthPage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métodos de pago',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 20),
        _buildDefaultPaymentMethods(),
        const SizedBox(height: 20),
        _buildAdditionalPaymentMethods(),
      ],
    ),
  );
}

Widget _buildDefaultPaymentMethods() {
  return Card(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métodos de pago por defecto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPaymentMethodIcon(Icons.account_balance_wallet, 'Monedero'),
              _buildPaymentMethodIcon(Icons.attach_money, 'Efectivo'),
              _buildPaymentMethodIcon(Icons.phone_android, 'Pago móvil'),
              Image.asset('assets/images/Paypal_Logo.png', height: 25),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildPaymentMethodIcon(IconData icon, String label) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 30, color: Colors.blue[700]),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ],
  );
}

Widget _buildAdditionalPaymentMethods() {
  return Card(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métodos de pago adicionales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Aumenta tus oportunidades ofreciendo más opciones de pago',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAdditionalPaymentMethod('Binance_LogoNew.png', 'Binance'),
              _buildAdditionalPaymentMethod('Zinli_Logo.png', 'Zinli'),
              _buildAdditionalPaymentMethod('Zelle_Logo.png', 'Zelle'),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildAdditionalPaymentMethod(String assetName, String label) {
  bool isSelected = selectedAdditionalPaymentMethods.contains(label);
  return GestureDetector(
    onTap: () {
      setState(() {
        if (isSelected) {
          selectedAdditionalPaymentMethods.remove(label);
        } else {
          selectedAdditionalPaymentMethods.add(label);
        }
      });
    },
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset('assets/images/$assetName', height: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue[700] : Colors.grey[700],
          ),
        ),
      ],
    ),
  );
}

Widget _buildFifthPage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Referencias laborales',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 20),
        _buildInfoCard(),
        const SizedBox(height: 30),
        ...List.generate(3, (index) => _buildReferenceInput(index)),
      ],
    ),
  );
}

Widget _buildInfoCard() {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.blue[700], size: 30),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            'Las referencias laborales son opcionales, pero aumentan significativamente sus posibilidades de aprobación.',
            style: TextStyle(color: Colors.blue[700], fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

Widget _buildReferenceInput(int index) {
  return Container(
    margin: const EdgeInsets.only(bottom: 25),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Referencia ${index + 1}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800]),
        ),
        const SizedBox(height: 20),
        _buildInputField('Nombre', Icons.person, (value) => _updateReference(index, 'name', value)),
        const SizedBox(height: 15),
        _buildInputField('Número telefónico', Icons.phone, (value) => _updateReference(index, 'phone', value), TextInputType.phone),
        const SizedBox(height: 15),
        _buildInputField('Trabajo realizado', Icons.work, (value) => _updateReference(index, 'job', value)),
      ],
    ),
  );
}

Widget _buildInputField(String label, IconData icon, Function(String) onChanged, [TextInputType? keyboardType]) {
  return TextFormField(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue[700]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.blue[50],
    ),
    keyboardType: keyboardType,
    onChanged: onChanged,
  );
}

  void _updateReference(int index, String field, String value) {
    if (jobReferences.length <= index) {
      jobReferences.add({});
    }
    setState(() {
      jobReferences[index][field] = value;
    });
  }

  Widget _buildSixthPage() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documentación y salud',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 20),
        _buildDocumentUpload('RIF', rifImage, _pickRifFile),
        const SizedBox(height: 16),
        _buildDocumentUpload('Curriculum Vitae (CV)', cvFile, _pickCvFile),
        const SizedBox(height: 20),
        _buildHealthInfoInput(),
        const SizedBox(height: 30),
        Center(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPostulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isSubmitting
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text(
                    'Enviar postulación',
                    style: TextStyle(fontSize: 18),
                  ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDocumentUpload(String documentType, File? file, Function() onTap) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                file == null ? Icons.upload_file : Icons.check_circle,
                size: 40,
                color: file == null ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file == null ? 'Subir $documentType' : '$documentType subido',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (file != null)
                      Text(
                        file.path.split('/').last,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildHealthInfoInput() {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información de salud (opcional):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ingrese información relevante sobre su salud...',
                prefixIcon: Icon(Icons.health_and_safety_rounded , color: Colors.blue[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                ),
                filled: true,
      fillColor: Colors.blue[50],
              ),
              onChanged: (value) {
                healthInfo = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            height: 8.0,
            width: index == _currentPage ? 24.0 : 8.0,
            decoration: BoxDecoration(
              color: index == _currentPage ? Colors.blue[700] : Colors.white,
              borderRadius: BorderRadius.circular(4.0),
            ),
          );
        }),
      ),
    );
  }

  // Actualizar _buildNavigationButtons para incluir la nueva página
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            ElevatedButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Anterior'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black87, 
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            const SizedBox(),

          if (_currentPage < 5) // Actualizado para incluir la nueva página
            ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              label: const Text('Siguiente'),
              icon: const Icon(Icons.arrow_forward),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }


  Future<void> _pickRifFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Permitir solo archivos PDF
    );

    if (result != null) {
      setState(() {
        rifImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickCvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Permitir solo archivos PDF
    );

    if (result != null) {
      setState(() {
        cvFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitPostulation() async {
  if (_formKey.currentState!.validate()) {
    if (rifImage == null || cvFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, adjunta todos los documentos requeridos.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Verificar si ya existe una postulación del usuario
      var existingPostulation = await FirebaseFirestore.instance
          .collection('postulations')
          .where('userID', isEqualTo: widget.combinedId)
          .get();

      if (existingPostulation.docs.isNotEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya has enviado una postulación.')),
        );
        return;
      }

      // Subir imágenes y archivos
      String rifImageUrl = await _uploadFile(rifImage!, 'rif_images/${widget.combinedId}');
      String cvFileUrl = await _uploadFile(cvFile!, 'cv_files/${widget.combinedId}');

      // Guardar postulación en Firestore
      await FirebaseFirestore.instance.collection('postulations').add({
        'userID': widget.combinedId,
        'selectedServices': selectedServices,
        'selectedAdditionalPaymentMethods': selectedAdditionalPaymentMethods,
        'selectedDays': selectedDays,
        'selectedTimesOfDay': selectedTimesOfDay,
        'rifImageUrl': rifImageUrl,
        'cvFileUrl': cvFileUrl,
        'healthInfo': healthInfo,
        'nationalTasks': nationalTasks,
        'ownVehicle': ownVehicle,
        'jobReferences': jobReferences,
        'postulationDate': FieldValue.serverTimestamp(),
        'approved': null,
      });

      // Agregar notificación al usuario
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.combinedId)
          .collection('notifications')
          .add({
        'description': 'Su postulación como agente MSA ha sido enviada y recibida con éxito. Nuestro equipo especializado esta evaluando su solicitud, de ser aprobada nos comunicaremos en la brevedad posible con usted para hacerle saber los siguientes pasos a seguir y lograr su inicio en nuestra comunidad de agentes ¡Muchas gracias por preferirnos!',
        'title': 'Postulación recibida',
        'read': false,
        'notificationDate': FieldValue.serverTimestamp(),
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postulación enviada')),
      );

      // Redirigir a la pantalla de perfil
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 4)),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la postulación: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

  Future<String> _uploadFile(File file, String path) async {
    Reference ref = FirebaseStorage.instance.ref().child(path);
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
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
            _currentProfileImageUrl = snapshot.data()!['profileImageUrl'] ?? '';
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
                      ).animate().fadeIn().slideX(),
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
                        ).animate().fade().scale(),
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
            leading: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFF08143c)),
            title: const Text('Clave de pago'),
            onTap: () {
              OneContext().push(
                MaterialPageRoute(
                  builder: (context) => const ChangePaymentKeyScreen(),
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
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
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
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
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
                    borderSide: const BorderSide(color: Color(0xFF08143c)),
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
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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
                maxLength: 4,
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

  String _formatDate(Timestamp? timestamp,
      {bool includeTime = false, bool includeWeekday = false}) {
    if (timestamp == null) return 'No disponible';

    String formattedDate = DateFormat('dd/MM/yyyy').format(timestamp.toDate());

    if (includeWeekday) {
      String weekday =
          DateFormat('EEEE', 'es_ES').format(timestamp.toDate()).toLowerCase();
      weekday =
          '${weekday[0].toUpperCase()}${weekday.substring(1)}'; // Poner la primera letra en mayúscula
      formattedDate = "$weekday $formattedDate";
    }

    if (includeTime) {
      formattedDate =
          "$formattedDate a las ${DateFormat('hh:mm a').format(timestamp.toDate())}";
    }

    return formattedDate;
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mi Cuenta',
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
            return const Center(
                child: CupertinoActivityIndicator(
              radius: 16,
              color: Colors.green,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final userData = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFE0E0E0),
                      child: Text(
                        '${userData['name'][0]}${userData['lastName'][0]}',
                        style: const TextStyle(
                            fontSize: 30, color: Color(0xFF08143c)),
                      ),
                    ).animate().fade().scale(),
                    const SizedBox(height: 20),
                    Text(
                      '${userData['name']} ${userData['lastName']}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF08143c)),
                    ).animate().fadeIn(),
                    const SizedBox(height: 30),
                    _buildInfoCard(
                      icon: Icons.person,
                      title: 'Género',
                      subtitle: userData['gender'] ?? 'No especificado',
                    ),
                    _buildInfoCard(
                      icon: Icons.email,
                      title: 'Correo electrónico',
                      subtitle: userData['email'],
                    ),
                    _buildInfoCard(
                      icon: Icons.phone,
                      title: 'Número telefónico',
                      subtitle: userData['phone'] ?? 'No especificado',
                    ),
                    _buildInfoCard(
                      icon: Icons.cake,
                      title: 'Fecha de nacimiento',
                      subtitle: _formatDate(userData['birthDate']),
                    ),
                    _buildInfoCard(
                      icon: Icons.calendar_today,
                      title: 'Apertura de la cuenta',
                      subtitle: _formatDate(userData['registrationDate'],
                          includeTime: true, includeWeekday: true),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No se encontraron datos'));
          }
        },
      ),
    );
  }

  Widget _buildInfoCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Card(
      color: Colors.blueGrey[50],
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF08143c)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF08143c))),
        subtitle:
            Text(subtitle, style: const TextStyle(color: Colors.blueGrey)),
      ),
    ).animate().fadeIn().slideX();
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
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
                      Image.asset('assets/images/IconSend.png', width: 24),
                      const InternalMessagingScreen(),
                    ),
                    _buildSupportOption(
                      context,
                      'Correo electrónico',
                      const Icon(Icons.email, color: Color(0xFF1ca424)),
                      () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'msasupport@gmail.com',
                          query: encodeQueryParameters({
                            'subject': 'Soporte de MSA',
                            'body': 'Hola Soporte, necesito ayuda con...'
                          }),
                        );

                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          await Clipboard.setData(const ClipboardData(
                              text: 'manueldelga2018@gmail.com'));
                          OneContext().showSnackBar(
                            builder: (_) => const SnackBar(
                              content: Text(
                                  'Dirección de correo copiada al portapapeles'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                    _buildSupportOption(
                      context,
                      'Vía WhatsApp',
                      Image.asset('assets/images/WhatsApp_Logo.png', width: 24),
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
    Widget icon, // Cambiado a Widget para aceptar tanto Icon como Image
    dynamic onTap,
  ) {
    return ListTile(
      leading: icon, // Ahora puede ser una imagen o un ícono
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF1ca424)),
      onTap: onTap is Function
          ? () => onTap()
          : (onTap is Widget
              ? () => OneContext().push(
                    MaterialPageRoute(builder: (context) => onTap),
                  )
              : null),
    );
  }
}

class FrequentQuestionsScreen extends StatefulWidget {
  const FrequentQuestionsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FrequentQuestionsScreenState createState() =>
      _FrequentQuestionsScreenState();
}

class _FrequentQuestionsScreenState extends State<FrequentQuestionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Preguntas frecuentes'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '¿Que dudas tienes?',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('faq').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Ocurrió un error'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CupertinoActivityIndicator(
                    radius: 16,
                    color: Colors.green,
                  ));
                }

                final faqDocs = snapshot.data!.docs;
                // Ordenar por ID de documento
                faqDocs.sort((a, b) => a.id.compareTo(b.id));
                // Filtrar por pregunta
                final filteredDocs = faqDocs
                    .where((doc) => doc['question']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final faq = filteredDocs[index];
                    final data = faq.data() as Map<String, dynamic>?;
                    return FAQItem(
                      question: faq['question'],
                      answer: faq['answer'],
                      publicationDate:
                          (faq['publicationDate'] as Timestamp).toDate(),
                      imageUrl: data != null && data.containsKey('FaqImageUrl')
                          ? data['FaqImageUrl']
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  final DateTime publicationDate;
  final String? imageUrl;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
    required this.publicationDate,
    this.imageUrl,
  });

  // ignore: library_private_types_in_public_api
  @override
  // ignore: library_private_types_in_public_api
  _FAQItemState createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: _expanded ? Colors.green : Colors.blueGrey,
          width: 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent), // Elimina las líneas
        child: ExpansionTile(
          // Eliminamos la decoración por defecto del ExpansionTile
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          backgroundColor: Colors
              .transparent, // Asegura que no haya fondo detrás de las respuestas
          trailing: Padding(
            // <-- Añade este padding al trailing
            padding:
                const EdgeInsets.only(right: 16.0), // Ajusta el espacio aquí
            child: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.green,
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              widget.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.answer),
                  const SizedBox(height: 8),
                  if (widget.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Publicado el ${DateFormat('dd/MM/yyyy').format(widget.publicationDate)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
          onExpansionChanged: (expanded) {
            setState(() {
              _expanded = expanded;
            });
          },
        ),
      ),
    );
  }
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Acerca de la app'),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF08143c)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/MSA_LogoTemporal.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Mobile Services App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text('Versión: ${snapshot.data!.version}');
                } else {
                  return const Text('Versión: Cargando...');
                }
              },
            ),
            const SizedBox(height: 20),
            const Text('© 2024 MSA Inc.'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Función para el botón de licencias (aún no implementada)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Licencias'),
            ),
          ],
        ),
      ),
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
