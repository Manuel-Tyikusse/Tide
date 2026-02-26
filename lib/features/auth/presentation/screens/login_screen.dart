import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tide/core/clients/supabase_client.dart';
import 'package:tide/features/navigation/main_navigation.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? toggleTheme; 
  const LoginScreen({super.key, this.toggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); 
  final _formKey = GlobalKey<FormState>();
  final _client = TideClient();

  bool _isLoading = false;
  bool _isLoginMode = true; 
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        print("DEBUG: Iniciando SignIn para ${_emailController.text}");
        await _client.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        print("DEBUG: Iniciando SignUp para ${_emailController.text} com username: ${_usernameController.text}");
        await _client.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          username: _usernameController.text.trim(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada! Verifica o teu email.')),
          );
          setState(() => _isLoginMode = true); 
        }
      }

      if (mounted && _isLoginMode) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } on AuthException catch (e) {
      print("DEBUG ERROR (Auth): ${e.message}");
      setState(() => _errorMessage = e.message);
    } catch (e) {
      print("DEBUG ERROR (Unexpected): $e");
      setState(() => _errorMessage = 'Ocorreu um erro inesperado.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print("DEBUG: Iniciando Google Sign In");
      await _client.signInWithGoogle();
    } catch (e) {
      print("DEBUG ERROR (Google): $e");
      setState(() => _errorMessage = 'Erro ao conectar com Google.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.whatshot_outlined, size: 80, color: Color(0xFF1A73E8)),
                const SizedBox(height: 30),
                Text(
                  _isLoginMode ? 'Bem-vindo de volta' : 'Cria a tua conta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter( // CORRIGIDO: googleSans para inter
                    color: const Color(0xFF1F1F1F), 
                    fontSize: 26, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      _errorMessage!, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)
                    ),
                  ),
                
                if (!_isLoginMode) ...[
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Color(0xFF1F1F1F)),
                    decoration: _inputDecoration('Username', Icons.person_outline),
                    validator: (v) => (v == null || v.isEmpty) ? 'Username obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Color(0xFF1F1F1F)),
                  decoration: _inputDecoration('E-mail', Icons.alternate_email),
                  validator: (v) => (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF1F1F1F)),
                  decoration: _inputDecoration('Password', Icons.lock_outline),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 25),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text(
                          'Continuar', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    setState(() => _isLoginMode = !_isLoginMode);
                  },
                  child: Text(
                    _isLoginMode ? 'Criar uma conta nova' : 'Já tenho uma conta',
                    style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black12)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("ou", style: TextStyle(color: Colors.black26, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.black12)),
                  ],
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, color: Color(0xFF1F1F1F), size: 30),
                  label: const Text('Continuar com Google', style: TextStyle(color: Color(0xFF1F1F1F))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.black12),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF1F3F4),
      prefixIcon: Icon(icon, color: Colors.black45, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: BorderSide.none
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}
