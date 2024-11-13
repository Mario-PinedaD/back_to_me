import 'package:flutter/material.dart';

class PageUser extends StatefulWidget {

  //Constructor
  PageUser({Key? key}) : super(key: key);

  @override
  _PageUserState createState() => _PageUserState();
}

class _PageUserState extends State<PageUser> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                SizedBox(height: 30),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(
                    "assets/mario.jpg",
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Pineda Domínguez',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Mario Alfredo',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              color: Color(0xFF1B396A),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OptionButton(
                    icon: Icons.account_circle,
                    label: 'Información de la cuenta',
                    content: 'Aquí se muestra la información de la cuenta.',
                  ),
                  SizedBox(height: 20),
                  OptionButton(
                    icon: Icons.history,
                    label: 'Historial de Objetos',
                    content: 'Aquí se muestra el historial de objetos.',
                  ),
                  SizedBox(height: 20),
                  OptionButton(
                    icon: Icons.contact_support,
                    label: 'Contacto y Soporte',
                    content:
                        '"Back To Me" es un proyecto desarrollado por alumnos de ingeniería en sistemas computacinoales en el ITVER, en caso de cualquier aclaración y problemática favor de contactar al: 2299408506',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;

  OptionButton(
      {required this.icon, required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isDismissible: true, // Permite cerrar al tocar fuera de la ventana
          enableDrag: true, // Permite cerrarla deslizando hacia abajo
          builder: (BuildContext context) {
            return Container(
              padding: EdgeInsets.all(16),
              height: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(content),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SizedBox(width: 20),
            Icon(icon, size: 30, color: Colors.black),
            SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            )
          ],
        ),
      ),
    );
  }
}
