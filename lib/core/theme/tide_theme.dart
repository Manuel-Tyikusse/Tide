import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TideTheme {
  static const Color _black = Color(0xFF000000);
  static const Color _offWhite = Color(0xFFE0E0E0); 
  static const Color _secondaryGrey = Color(0xFF9E9E9E); 
  static const Color _inputFieldGrey = Color(0xFF1A1A1A);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            color: _offWhite,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _offWhite,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _offWhite,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _offWhite,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _secondaryGrey,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputFieldGrey,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _offWhite.withAlpha(26)), // Correção: withOpacity(0.1)
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _secondaryGrey),
        ),
        hintStyle: TextStyle(color: _offWhite.withAlpha(77), fontSize: 14), // Correção: withOpacity(0.3)
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _offWhite,
          foregroundColor: _black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _black,
        selectedItemColor: _offWhite,
        unselectedItemColor: _secondaryGrey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      
      dividerTheme: const DividerThemeData(
        color: _inputFieldGrey,
        thickness: 1,
        space: 1,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _offWhite,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        iconTheme: IconThemeData(color: _offWhite),
      ),
    );
  }
}
