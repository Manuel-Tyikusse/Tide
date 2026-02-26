
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.whatshot_outlined,
          size: size,
          color: Colors.deepPurpleAccent,
        ),
        const SizedBox(height: 8),
        Text(
          'Tide',
          style: GoogleFonts.pacifico(
            fontSize: size * 0.4,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
