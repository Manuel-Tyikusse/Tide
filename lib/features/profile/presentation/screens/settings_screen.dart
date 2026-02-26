import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tide/core/clients/supabase_client.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("DEBUG: Acedendo às Definições.");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "DEFINIÇÕES", 
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black)
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Colors.black.withOpacity(0.05), height: 1),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader("CONTA"),
          _buildSettingsTile(
            context, 
            icon: Icons.person_outline_rounded, 
            title: "Informações Pessoais", 
            onTap: () => _showPlaceholder(context, "Informações Pessoais")
          ),
          _buildSettingsTile(
            context, 
            icon: Icons.lock_outline_rounded, 
            title: "Privacidade e Segurança", 
            onTap: () => _showPlaceholder(context, "Privacidade")
          ),
          
          _buildSectionHeader("PREFERÊNCIAS"),
          _buildSettingsTile(
            context, 
            icon: Icons.notifications_none_rounded, 
            title: "Notificações", 
            onTap: () => _showPlaceholder(context, "Notificações")
          ),
          _buildSettingsTile(
            context, 
            icon: Icons.language_rounded, 
            title: "Idioma", 
            subtitle: "Português",
            onTap: () => _showPlaceholder(context, "Idioma")
          ),

          _buildSectionHeader("SUPORTE"),
          _buildSettingsTile(
            context, 
            icon: Icons.help_outline_rounded, 
            title: "Centro de Ajuda", 
            onTap: () => _showPlaceholder(context, "Ajuda")
          ),
          _buildSettingsTile(
            context, 
            icon: Icons.info_outline_rounded, 
            title: "Sobre o Tide", 
            onTap: () => _showPlaceholder(context, "Sobre")
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextButton(
              onPressed: () async {
                print("DEBUG: Logout solicitado.");
                await TideClient().signOut();
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFFFFEBEE),
              ),
              child: Text(
                "TERMINAR SESSÃO", 
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title, 
        style: GoogleFonts.inter(
          color: const Color(0xFF1A73E8), 
          fontSize: 11, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.0
        )
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon, 
    required String title, 
    String? subtitle,
    required VoidCallback onTap
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.black54, size: 22),
      title: Text(
        title, 
        style: GoogleFonts.inter(color: const Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w600)
      ),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(color: Colors.black38, fontSize: 13)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black12, size: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _showPlaceholder(BuildContext context, String title) {
    print("DEBUG: A abrir ecrã de placeholder: $title");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: Color(0xFFF1F3F4), shape: BoxShape.circle),
                  child: const Icon(Icons.construction_rounded, color: Colors.black26, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  "Funcionalidade em breve", 
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    "Estamos a trabalhar para trazer as definições de $title para a comunidade Tide.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black45, height: 1.5),
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
