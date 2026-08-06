import 'package:flutter/material.dart';

/// Bildergalerie / Auswahl der Ausmalbilder.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Platzhalter: hier kommen später die Ausmalbilder hin.
          const SafeArea(
            child: SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}
