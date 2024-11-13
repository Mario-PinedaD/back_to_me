// LostObjectMapPage.dart

import 'package:flutter/material.dart';

class LostObjectMapPage extends StatelessWidget {
  final Map<String, double> mapLocation; // {'x': porcentaje, 'y': porcentaje}

  LostObjectMapPage({required this.mapLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubicación del Objeto Perdido', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF1B396A),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double imageWidth = constraints.maxWidth;
          double imageHeight = constraints.maxHeight;

          double xPercentage = mapLocation['x'] ?? 0.0;
          double yPercentage = mapLocation['y'] ?? 0.0;

          double x = xPercentage * imageWidth;
          double y = yPercentage * imageHeight;

          return Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/mapa_escuela.png',
                        fit: BoxFit.cover,
                        width: imageWidth,
                        height: imageHeight,
                      ),
                      Positioned(
                        left: x,
                        top: y,
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ubicación aproximada donde se encontró el objeto perdido.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
