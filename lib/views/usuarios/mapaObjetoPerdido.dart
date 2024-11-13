// map_selection_page.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:typed_data';

class MapSelectionPage extends StatefulWidget {
  final String mapImagePath;

  MapSelectionPage({required this.mapImagePath});

  @override
  _MapSelectionPageState createState() => _MapSelectionPageState();
}

class _MapSelectionPageState extends State<MapSelectionPage>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  TapDownDetails? _doubleTapDetails;
  Offset? _markerPosition;
  late ui.Image _mapImage;
  bool _imageLoaded = false;

  // Definir una GlobalKey
  final GlobalKey _interactiveViewerKey = GlobalKey();

  // Variable para el tamaño del ícono
  double _iconSize = 48.0; // Tamaño base del ícono

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _loadMapImage();
  }

  Future<void> _loadMapImage() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(widget.mapImagePath);
      final list = Uint8List.view(data.buffer);
      final codec = await ui.instantiateImageCodec(list);
      final frame = await codec.getNextFrame();
      setState(() {
        _mapImage = frame.image;
        _imageLoaded = true;
      });
    } catch (e) {
      print("Error al cargar la imagen del mapa: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la imagen del mapa.')),
      );
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  // Listener para los cambios en la transformación
  void _onTransformationChanged() {
    // Extraer el factor de escala de la matriz de transformación
    double currentScale = _transformationController.value.getMaxScaleOnAxis();

    // Calcular el nuevo tamaño del ícono
    double newSize = 48.0 / currentScale;

    // Limitar el tamaño del ícono para evitar que se vuelva demasiado pequeño o grande
    newSize = newSize.clamp(24.0, 48.0);

    setState(() {
      _iconSize = newSize;
    });
  }

  // Función para manejar el toque y colocar el marcador
  void _handleTapDown(TapDownDetails details) {
    final RenderBox? box = _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final Offset localOffset = box.globalToLocal(details.globalPosition);

      // Aplicar la transformación inversa para obtener las coordenadas originales de la imagen
      final Matrix4 inverseMatrix = Matrix4.inverted(_transformationController.value);
      final Offset imageOffset = MatrixUtils.transformPoint(
        inverseMatrix,
        localOffset,
      );

      setState(() {
        _markerPosition = imageOffset;
      });
    }
  }

  // Función para manejar el doble toque para hacer zoom
  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }
  }

  // Función para guardar la ubicación
  void _saveLocation() {
    if (_markerPosition != null) {
      // Normalizar las coordenadas
      final double x = _markerPosition!.dx / _mapImage.width;
      final double y = _markerPosition!.dy / _mapImage.height;

      Navigator.of(context).pop({'x': x, 'y': y});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un punto en el mapa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_imageLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Seleccionar Ubicación'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Seleccionar Ubicación'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveLocation,
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        onTapDown: _handleTapDown, // Detectar el toque
        child: InteractiveViewer(
          key: _interactiveViewerKey, // Asignar la GlobalKey
          transformationController: _transformationController,
          maxScale: 5.0,
          minScale: 1.0,
          child: Stack(
            children: [
              Image.asset(
                widget.mapImagePath,
                fit: BoxFit.contain,
              ),
              if (_markerPosition != null)
                Positioned(
                  left: _markerPosition!.dx - (_iconSize / 2),
                  top: _markerPosition!.dy - (_iconSize),
                  child: Icon(
                    Icons.add,
                    size: _iconSize,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
