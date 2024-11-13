
// full_screen_image_viewer.dart
import 'dart:io';
import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  FullScreenImageViewer({required this.images, required this.initialIndex});

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  double _verticalDrag = 0.0;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  // Variables para manejar escalado y rotación
  double _scale = 1.0;
  double _previousScale = 1.0;
  double _rotation = 0.0;
  double _previousRotation = 0.0;
  Offset _position = Offset.zero;
  Offset _previousPosition = Offset.zero;

  // Variables para manejar gestos
  int _pointerCount = 0;
  bool _isScaling = false;
  Offset _dragStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), //
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_animationController);
  }

  // Método para cerrar el visor
  void _closeViewer() {
    Navigator.of(context).pop();
  }

  // Método para manejar el doble toque
  void _handleDoubleTap() {
    setState(() {
      if (_scale != 1.0 || _rotation != 0.0 || _position != Offset.zero) {
        // Restablecer a estado original
        _scale = 1.0;
        _previousScale = 1.0;
        _rotation = 0.0;
        _previousRotation = 0.0;
        _position = Offset.zero;
        _previousPosition = Offset.zero;
      } else {
        // Aplicar zoom
        _scale = 2.0;
        _previousScale = 2.0;
      }
    });
  }

  // Métodos para manejar gestos de escala y rotación
  void _handleScaleStart(ScaleStartDetails details) {
    if (_pointerCount >= 2) {
      setState(() {
        _isScaling = true;
        _previousScale = _scale;
        _previousRotation = _rotation;
        _previousPosition = _position;
      });
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isScaling) {
      setState(() {
        _scale = (_previousScale * details.scale).clamp(1.0, 4.0);
        _rotation = _previousRotation + details.rotation;
        _position += details.focalPointDelta;
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isScaling) {
      // Reiniciar bandera de escalado
      setState(() {
        _isScaling = false;
      });
    }
  }

  // Métodos para manejar desplazamiento vertical
  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isScaling) {
      setState(() {
        _verticalDrag += details.delta.dy;
      });
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isScaling) {
      if (_verticalDrag.abs() > 100) {
        _animationController.forward().then((_) => _closeViewer());
      } else {
        setState(() {
          _verticalDrag = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Listener(
        onPointerDown: (_) => setState(() { _pointerCount +=1; }),
        onPointerUp: (_) => setState(() { _pointerCount -=1; }),
        child: GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          onDoubleTap: _handleDoubleTap,
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      // Restablecer transformaciones al cambiar de página
                      _scale = 1.0;
                      _previousScale = 1.0;
                      _rotation = 0.0;
                      _previousRotation = 0.0;
                      _position = Offset.zero;
                      _previousPosition = Offset.zero;
                      _verticalDrag = 0.0;
                    });
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onScaleStart: _handleScaleStart,
                      onScaleUpdate: _handleScaleUpdate,
                      onScaleEnd: _handleScaleEnd,
                      onDoubleTap: _handleDoubleTap,
                      child: Transform.translate(
                        offset: Offset(_position.dx, _position.dy + _verticalDrag),
                        child: Transform.rotate(
                          angle: _rotation,
                          child: Transform.scale(
                            scale: _scale,
                            child: Center(
                              child: Image.file(
                                widget.images[index],
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Botón de cerrar y contador de imágenes, visibles solo con un dedo
                if (_pointerCount <=1)
                  Positioned(
                    top: 40,
                    left: 16,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: _closeViewer,
                    ),
                  ),
                if (_pointerCount <=1)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: Text(
                          '${_currentIndex + 1} de ${widget.images.length}',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
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