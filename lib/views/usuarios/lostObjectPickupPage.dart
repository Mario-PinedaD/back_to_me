// lost_object_pickup_page.dart

import 'package:flutter/material.dart';

class LostObjectPickupPage extends StatelessWidget {
  // Coordenadas fijas para el punto de recolección
  final Offset pickupLocation = Offset(150.0, 450.0); // Ajusta según tu mapa

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lost Objects Pickup'),
        backgroundColor: Color(0xFF1B396A),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              panEnabled: false,
              scaleEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              child: Stack(
                children: [
                  Image.asset(
                    'assets/mapa_escuela.png',
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    left: pickupLocation.dx,
                    top: pickupLocation.dy,
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
              'Puedes recoger los objetos perdidos en este punto durante las horas de atención.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
