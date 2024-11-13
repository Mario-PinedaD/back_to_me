// add_lost_object_page.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/usuarioRegistrado.dart';
import '../administradorBD/usuariosBD.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'fullscreen_image_detail.dart';
import 'mapaObjetoPerdido.dart';

class AddLostObjectPage extends StatefulWidget {
  @override
  _AddLostObjectPageState createState() => _AddLostObjectPageState();
}

class _AddLostObjectPageState extends State<AddLostObjectPage> {
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  String _description = '';
  String _objectType = '';
  String _locationFound = '';
  bool _isUploadingImage = false;
  bool _isUploadingData = false;
  final List<File> _selectedImages = [];
  Offset? _mapLocation; // To store the selected location

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Máximo 5 imágenes permitidas.')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Convertir XFile a File
      final File file = File(pickedFile.path);

      // Obtener el tamaño del archivo antes de la compresión y convertirlo a MB
      final originalSizeBytes = await pickedFile.length();
      final originalSizeMB = originalSizeBytes / 1048576;
      print("Tamaño original: ${originalSizeMB.toStringAsFixed(2)} MB");

      // Comprimir la imagen
      final compressedFile = await _compressFile(file);

      if (compressedFile != null) {
        setState(() {
          _selectedImages.add(compressedFile);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al comprimir la imagen.')),
        );
      }
    }
  }

  Future<File?> _compressFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
    final splitted = filePath.substring(0, lastIndex);
    final outPath = "${splitted}_compressed.jpg";

    try {
      // Asumiendo que FlutterImageCompress.compressAndGetFile devuelve un File.
      var compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        minWidth: 1280,
        minHeight: 720,
        quality: 30,
      );

      if (compressedFile != null) {
        File resultFile = File(compressedFile.path);

        final compressedSizeBytes = resultFile.lengthSync();
        final compressedSizeMB = compressedSizeBytes / 1048576;
        print("Tamaño después de la compresión: ${compressedSizeMB.toStringAsFixed(2)} MB");

        final originalSizeBytes = file.lengthSync();
        final reductionPercentage = (1 - compressedSizeBytes / originalSizeBytes) * 100;
        print("Reducción del tamaño: ${reductionPercentage.toStringAsFixed(2)}%");

        return resultFile;
      }
    } catch (e) {
      print("Error al comprimir imagen: $e");
    }

    return null;
  }

  List<Widget> _buildCarouselItems(BuildContext context) {
    List<Widget> items = [];
    for (var i = 0; i < _selectedImages.length; i++) {
      var file = _selectedImages[i];
      var item = Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    images: _selectedImages,
                    initialIndex: i,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          // Botón para eliminar la imagen
          Container(
            color: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.white),
              onPressed: () {
                setState(() {
                  _selectedImages.removeAt(i);
                });
              },
            ),
          ),
        ],
      );
      items.add(item);
    }

    // Si hay menos de 5 imágenes, añadir al final el botón para añadir más imágenes.
    if (_selectedImages.length < 5) {
      Widget addButton = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.grey[300],
          child: GestureDetector(
            onTap: _pickImage,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                  Text("Añadir imagen"),
                ],
              ),
            ),
          ),
        ),
      );

      items.add(addButton);
    }

    return items;
  }

  // Función para subir la imagen y los datos a Firebase
  Future<void> _uploadData() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor, añade al menos una imagen.",
            style: TextStyle(color: Colors.white, fontSize: 16.0),
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isUploadingData = true;
    });

    List<String> imageUrls = [];
    try {
      int totalImages = _selectedImages.length;
      for (int i = 0; i < totalImages; i++) {
        setState(() {
          _isUploadingImage = true;
        });

        File imageFile = _selectedImages[i];
        String fileName = 'lost_objects/${DateTime.now().millisecondsSinceEpoch}_${i}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(imageFile);

        // Escuchar el estado de la subida
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          switch (snapshot.state) {
            case TaskState.running:
              print('Subiendo imagen ${i + 1} de $totalImages...');
              break;
            case TaskState.success:
              print('Imagen ${i + 1} subida exitosamente.');
              break;
            case TaskState.error:
              print('Error al subir la imagen ${i + 1}.');
              break;
            default:
              break;
          }
        });

        // Esperar a que la subida finalice
        TaskSnapshot taskSnapshot = await uploadTask;
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);

        setState(() {
          _isUploadingImage = false;
        });

        // Actualizar el progreso en el UI si lo deseas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imagen ${i + 1} de $totalImages subida.')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingData = false;
        _isUploadingImage = false;
      });
      print("Error al subir las imágenes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir las imágenes.')),
      );
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    final Usuario? currentUser = authState.user;

    if (currentUser == null) {
      setState(() {
        _isUploadingData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debes iniciar sesión para subir una imagen.')),
      );
      return;
    }

    try {
      CollectionReference objects = FirebaseFirestore.instance.collection('objetos_perdidos');
      await objects.add({
        'descripcion': _description,
        'tipoObjeto': _objectType,
        'tipoObjetoBusqueda': _objectType.toLowerCase(),
        'lugarEncontrado': _locationFound,
        'estadoReclamacion': 'No reclamado',
        'imagenUrl': imageUrls.first, // URL de la primera imagen
        'imageUrls': imageUrls, // Lista de URLs de imágenes
        'nombreEncontrado': currentUser.nombre,
        'uidEncontrado': currentUser.id,
        'timestamp': FieldValue.serverTimestamp(),
        'mapLocation': _mapLocation != null
            ? {'x': _mapLocation!.dx, 'y': _mapLocation!.dy}
            : null,
      });
    } catch (e) {
      setState(() {
        _isUploadingData = false;
      });
      print("Error al guardar los datos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar los datos.')),
      );
      return;
    }

    setState(() {
      _isUploadingData = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Objeto perdido agregado exitosamente.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF1B396A);
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Objeto Perdido', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 200,
                      enableInfiniteScroll: false,
                      enlargeCenterPage: true,
                    ),
                    items: _buildCarouselItems(context),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration:
                    InputDecoration(labelText: 'Descripción del objeto'),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese una descripción';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _description = value!;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration:
                    InputDecoration(labelText: '¿Qué objeto es?'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el tipo de objeto';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _objectType = value!;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration:
                    InputDecoration(labelText: '¿Dónde fue encontrado?'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese el lugar donde fue encontrado';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _locationFound = value!;
                    },
                  ),
                  // Inside your build method, in the ListView children
                  SizedBox(height: 16),
                  Text(
                    _mapLocation != null
                        ? 'Ubicación seleccionada en el mapa.'
                        : 'No se ha seleccionado ubicación en el mapa.',
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _selectLocationOnMap,
                    child: Text('Seleccionar ubicación en el mapa'),
                  ),

                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isUploadingData ? null : _uploadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isUploadingData
                        ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : Text('Guardar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          if (_isUploadingImage || _isUploadingData)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }


  void _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionPage(mapImagePath: 'assets/mapa_escuela.png'),
      ),
    );

    if (result != null && result is Map<String, double>) {
      setState(() {
        _mapLocation = Offset(result['x']!, result['y']!);
      });
    }
  }

}


