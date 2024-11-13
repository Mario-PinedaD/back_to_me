// lost_object_detail_page.dart

import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../services/usuarioRegistrado.dart';
import '../administradorBD/objetosPerdidosBD.dart';
import '../administradorBD/reclamacionesBD.dart';
import '../administradorBD/usuariosBD.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../usuarios/LostObjectMapPage.dart';
import '../usuarios/fullscreen_image_detail.dart';
import '../usuarios/lostObjectPickupPage.dart';


class LostObjectDetailPageAdmin extends StatefulWidget {
  final LostObject lostObject;

  LostObjectDetailPageAdmin({required this.lostObject});

  @override
  _LostObjectDetailPageAdminState createState() => _LostObjectDetailPageAdminState();
}

class _LostObjectDetailPageAdminState extends State<LostObjectDetailPageAdmin> {
  final Color _primaryColor = Color(0xFF1B396A);

  // Controladores y variables para el formulario de reclamación
  final _formKey = GlobalKey<FormState>();
  final _textoController = TextEditingController();
  File? _imageFile;
  List<String> imagenesUrls = []; // Inicializa con las URLs de las imágenes
  bool _isSubmitting = false;
  List<File> _selectedImages = []; // Lista de archivos locales
  List<File> _selectedImage = []; // Lista de archivos locales

  // Variables para mensajes de advertencia
  final List<String> _warningMessages = [
    "Reclamar objetos perdidos que no te pertenecen puede ser considerado como robo.",
    "No reclames objetos perdidos que no son de tu propiedad.",
    "Asegúrate de que el objeto perdido sea tuyo antes de reclamarlo.",
    "Reclamar objetos sin ser el dueño legítimo puede tener consecuencias legales.",
    "Por favor, verifica que eres el propietario del objeto antes de reclamarlo."
  ];
  String _currentWarningMessage = "";
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadImages(widget.lostObject.imageUrls);
    print("numero de urls: ${widget.lostObject.imageUrls!.length}");

    // Inicializar el mensaje de advertencia
    _currentWarningMessage = _warningMessages[0];

  }


  // Formatear la fecha
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  // Función para seleccionar imagen de la galería
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Función para subir la imagen a Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('reclamaciones/${widget.lostObject.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error al subir la imagen: $e');
      return null;
    }
  }

  // Función para enviar la reclamación
  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    // Mostrar el diálogo de carga con mensajes de advertencia
    _showLoadingDialog();

    DateTime startTime = DateTime.now();

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
      }

      // Obtener información del usuario actual
      final authState = Provider.of<AuthState>(context, listen: false);
      final Usuario? currentUser = authState.user;

      // Crear una nueva reclamación
      Reclamacion nuevaReclamacion = Reclamacion(
        uidReclamante: currentUser!.id,
        fotoReclamante: currentUser.urlimagen,
        nombreReclamante: currentUser.nombre,
        apellidoReclamante: currentUser.apellido,
        estadoReclamacion: 'Pendiente',
        textoReclamacion: _textoController.text.trim(),
        imagenReclamacionUrl: imageUrl,
        horaReclamacion: DateTime.now(),
      );

      // Añadir la reclamación a la lista existente
      List<Reclamacion> nuevasReclamaciones =
      List.from(widget.lostObject.reclamaciones)..add(nuevaReclamacion);

      // **Crear o actualizar la lista de reclamacionesUids**
      // Extraer los UIDs de los reclamantes existentes y agregar el nuevo UID
      List<String> reclamacionesUids = nuevasReclamaciones
          .map((reclamacion) => reclamacion.uidReclamante)
          .toSet()
          .toList(); // Usamos toSet para evitar duplicados

      // Actualizar el objeto en Firestore
      await FirebaseFirestore.instance
          .collection('objetos_perdidos')
          .doc(widget.lostObject.id)
          .update({
        'reclamaciones': nuevasReclamaciones.map((r) => r.toMap()).toList(),
        'reclamacionesUids': reclamacionesUids,
        'estadoReclamacion': 'Pendiente',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reclamación enviada exitosamente.')),
      );

      // Navegar a la página de recolección de objetos perdidos
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LostObjectPickupPage(),
        ),
      );
    } catch (e) {
      print('Error al enviar la reclamación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la reclamación.')),
      );
    }

    // Calcular el tiempo transcurrido
    DateTime endTime = DateTime.now();
    Duration elapsed = endTime.difference(startTime);

    // Determinar si se necesita esperar más tiempo
    if (elapsed < Duration(seconds: 5)) {
      await Future.delayed(Duration(seconds: 5) - elapsed);
    }

    setState(() {
      _isSubmitting = false;
    });

    // Cerrar el diálogo de carga si aún está abierto
    Navigator.of(context).pop(); // Cerrar el diálogo
    Navigator.of(context).pop(); // Cerrar la página actual
  }

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  bool _hasUserClaimed() {
    final authState = Provider.of<AuthState>(context, listen: false);
    final Usuario? currentUser = authState.user;
    return widget.lostObject.reclamaciones.any((reclamacion) => reclamacion.uidReclamante == currentUser?.id);
  }

  bool _isOwner() {
    final authState = Provider.of<AuthState>(context, listen: false);
    final Usuario? currentUser = authState.user;
    return widget.lostObject.uidEncontrado == currentUser?.id;
  }

  Future<void> _loadImages(List<String>? imageUrls) async {
    if (imageUrls == null || imageUrls.isEmpty) {
      return;
    }

    List<File> imageFiles = [];
    for (String url in imageUrls) {
      try {
        File imageFile = await _urlToFile(url);
        imageFiles.add(imageFile);
      } catch (e) {
        print("Error al descargar la imagen: $e");
        // Opcionalmente, maneja el error, por ejemplo, mostrando un mensaje al usuario
      }
    }

    setState(() {
      _selectedImages = imageFiles;
      print("Imagenes cargadas: ${_selectedImages.length}");
    });
  }

  Future<File> _urlToFile(String imageUrl) async {
    // Crear una instancia de Dio
    var dio = Dio();

    // Obtener una ubicación temporal en el sistema de archivos del dispositivo donde guardar el archivo
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    // Extraer el nombre del archivo de la URL
    String fileName = path.basename(imageUrl);

    // Combinar el camino temporal con el nombre del archivo
    String filePath = path.join(tempPath, fileName);

    try {
      // Descargar el archivo de la imagen de la URL
      Response response = await dio.download(imageUrl, filePath);

      // Si la descarga fue exitosa, devolver el archivo
      if (response.statusCode == 200) {
        return File(filePath);
      } else {
        throw Exception('Error al descargar la imagen: Estado HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al descargar la imagen: $e');
    }
  }


  // Método para construir los items del carousel
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
          /*Container(
            color: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.white),
              onPressed: () {
                setState(() {
                  _selectedImages.removeAt(i);
                });
              },
            ),
          ),*/
        ],
      );
      items.add(item);
    }

    // Si hay menos de 5 imágenes, añadir al final el botón para añadir más imágenes.
    /* if (_selectedImages.length < 5) {
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
    }*/

    return items;
  }


  bool _showClaimantList = false;

  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);
    final Usuario? currentUser = authState.user;
    bool isOwner = widget.lostObject.uidEncontrado == currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Detalles del objeto",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.people),
                Positioned(
                  right: 0,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      '${widget.lostObject.reclamaciones.length}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              setState(() {
                _showClaimantList = !_showClaimantList;
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(20.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _formatDate(widget.lostObject.timestamp),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Imagenes del objeto perdido
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 200,
                  enableInfiniteScroll: false,
                  enlargeCenterPage: true,
                  viewportFraction: 0.8,
                ),
                items: _buildCarouselItems(context),
              ),
            ),
            // Detalles del objeto perdido dentro de un Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 0.0),
                child: Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título del objeto
                        Text(
                          widget.lostObject.tipoObjeto,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        // Descripción
                        Text(
                          'Descripción:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.lostObject.descripcion,
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        // Lugar encontrado
                        Text(
                          'Encontrado en:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.lostObject.lugarEncontrado,
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 16),
                        // Estado de la reclamación (si existe)
                        widget.lostObject.estadoReclamacion != 'No reclamado'
                            ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado de la reclamación:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _primaryColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.lostObject.estadoReclamacion!,
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 16),
                          ],
                        )
                            : SizedBox.shrink(),

                        SizedBox(height: 16),
                        // Dentro de tu método build, después de mostrar los detalles
                        if (widget.lostObject.mapLocation != null)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LostObjectMapPage(
                                    mapLocation: widget.lostObject.mapLocation!,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.map, color: Colors.white),
                            label: Text('Ver ubicación en el mapa', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                            ),
                          ),

                        SizedBox(height: 24),

                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16),

            if (_showClaimantList)
            // Show the list of claimants
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lista de reclamaciones:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                      ),
                      SizedBox(height: 8),
                      _buildClaimantList(),
                    ],
                  ),
                )
            else
            // Show the claim form or appropriate message
              if (widget.lostObject.estadoReclamacion == 'Entregado')
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Este objeto ha sido entregado a su dueño: ${widget.lostObject.nombreReclamado}',
                    style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (isOwner)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Eres el usuario que encontró este objeto.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                )
              else if (_hasUserClaimed())
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Ya has enviado una reclamación para este objeto.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  )
                else
                // Show the claim form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Para reclamar este objeto, por favor proporciona una descripción detallada y evidencia si es posible.',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 16),
                          // Required text field
                          TextFormField(
                            controller: _textoController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: 'Descripción de la reclamación',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Este campo es obligatorio.';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Button to select optional image
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.photo, color: Colors.white),
                                label: _imageFile != null
                                    ? Text('Imagen seleccionada', style: TextStyle(color: Colors.white))
                                    : Text('No se ha seleccionado ninguna imagen', style: TextStyle(color: Colors.white)),
                                onPressed: _pickImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          // Button to submit the claim
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitClaim,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: _isSubmitting
                                ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                                : Text(
                              'Enviar reclamación',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }


  Widget _buildClaimantList() {
    if (widget.lostObject.reclamaciones.isEmpty) {
      return Text(
        'No hay reclamaciones para este objeto.',
        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
      );
    }

    if (widget.lostObject.estadoReclamacion == 'Entregado') {
      // Buscar la reclamación que tiene estado 'Entregado'
      Reclamacion? reclamacionEntregada = widget.lostObject.reclamaciones.firstWhere(
            (reclamacion) => reclamacion.estadoReclamacion == 'Entregado'
      );

      if (reclamacionEntregada != null) {
        // Mostrar información de a quién se entregó el objeto
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El objeto fue entregado a:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
            ),
            SizedBox(height: 8),
            Card(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: reclamacionEntregada.fotoReclamante.isNotEmpty
                      ? NetworkImage(reclamacionEntregada.fotoReclamante)
                      : AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                title: Text('${reclamacionEntregada.nombreReclamante} ${reclamacionEntregada.apellidoReclamante}'),
                subtitle: Text('Este es el usuario al que se le entregó el objeto.'),
                onTap: () {
                  // Mostrar detalles de la reclamación entregada
                  _showClaimDetailsDialog(reclamacionEntregada);
                },
              ),
            ),
          ],
        );
      } else {
        // No se encontró la reclamación con estado 'Entregado'
        return Text(
          'No se pudo encontrar la información del reclamante al que se entregó el objeto.',
          style: TextStyle(fontSize: 16, color: Colors.red),
        );
      }
    }

    // Si el objeto no ha sido entregado, mostrar la lista de reclamantes
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: widget.lostObject.reclamaciones.length,
      itemBuilder: (context, index) {
        final reclamacion = widget.lostObject.reclamaciones[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: reclamacion.fotoReclamante.isNotEmpty
                  ? NetworkImage(reclamacion.fotoReclamante)
                  : AssetImage('assets/default_avatar.png') as ImageProvider,
            ),
            title: Text('${reclamacion.nombreReclamante} ${reclamacion.apellidoReclamante}'),
            subtitle: Text(reclamacion.textoReclamacion, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: ElevatedButton(
              onPressed: () {
                _deliverObjectToClaimant(reclamacion);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Entregar'),
            ),
            onTap: () {
              // Mostrar el diálogo con detalles de la reclamación
              _showClaimDetailsDialog(reclamacion);
            },
          ),
        );
      },
    );
  }



  // Método para mostrar el diálogo con detalles de la reclamación
  void _showClaimDetailsDialog(Reclamacion reclamacion) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detalles de la reclamación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reclamante: ${reclamacion.nombreReclamante} ${reclamacion.apellidoReclamante}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Fecha de reclamación: ${_formatDateTime(reclamacion.horaReclamacion)}'),
                SizedBox(height: 8),
                Text('Descripción:'),
                Text(reclamacion.textoReclamacion),
                SizedBox(height: 16),
                if (reclamacion.imagenReclamacionUrl != null && reclamacion.imagenReclamacionUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      // Abrir imagen en pantalla completa
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(images: _selectedImage, initialIndex: 0),
                        ),
                      );
                    },
                    child: Image.network(
                      reclamacion.imagenReclamacionUrl!,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _loadImage(String imageUrl) async {
    try {
      File imageFile = await _urlToFile(imageUrl);
      setState(() {
        _selectedImage = [imageFile];
      });
    } catch (e) {
      print("Error al cargar la imagen: $e");
      // Opcionalmente, maneja el error, por ejemplo, mostrando un mensaje al usuario
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _deliverObjectToClaimant(Reclamacion reclamacion) async {
    // Mostrar diálogo de confirmación
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar entrega'),
        content: Text('¿Estás seguro de que deseas entregar el objeto a ${reclamacion.nombreReclamante}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Actualizar el objeto en Firestore
      try {
        // Actualizar el estado de las reclamaciones
        List<Reclamacion> updatedReclamaciones = widget.lostObject.reclamaciones.map((r) {
          if (r.uidReclamante == reclamacion.uidReclamante) {
            r.estadoReclamacion = 'Entregado';
          } else {
            r.estadoReclamacion = 'Rechazado';
          }
          return r;
        }).toList();

        await FirebaseFirestore.instance
            .collection('objetos_perdidos')
            .doc(widget.lostObject.id)
            .update({
          'estadoReclamacion': 'Entregado',
          'uidReclamado': reclamacion.uidReclamante,
          'nombreReclamado': reclamacion.nombreReclamante,
          'reclamaciones': updatedReclamaciones.map((r) => r.toMap()).toList(),
        });

        // Actualizar el estado local del objeto
        setState(() {
          widget.lostObject.estadoReclamacion = 'Entregado';
          widget.lostObject.uidReclamado = reclamacion.uidReclamante;
          widget.lostObject.nombreReclamado = reclamacion.nombreReclamante;
          widget.lostObject.reclamaciones = updatedReclamaciones;
        });

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Objeto entregado a ${reclamacion.nombreReclamante}')),
        );
      } catch (e) {
        print('Error al actualizar el objeto: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al entregar el objeto')),
        );
      }
    }
  }


  Future<void> _showLoadingDialog() async {
    _currentWarningMessage = _warningMessages[0];
    int messageIndex = 0;
    final random = Random();

    // Iniciar la rotación de mensajes cada 2 segundos
    _messageTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        messageIndex = random.nextInt(_warningMessages.length);
        _currentWarningMessage = _warningMessages[messageIndex];
      });
    });

    await showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar el diálogo tocando fuera
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  _currentWarningMessage,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Cancelar el temporizador cuando el diálogo se cierre
    _messageTimer?.cancel();
  }

}




