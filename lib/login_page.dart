import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'city_data_dashboard.dart'; // Navigate here after login

class LoginPage extends StatefulWidget {
  final SupabaseClient supabaseClient;
  
  const LoginPage({super.key, required this.supabaseClient});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResponse res = await widget.supabaseClient.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return; // Check if the widget is still in the tree

      if (res.user != null) {
        // Navigate to the main dashboard on success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CityDataDashboard()),
        );
      } else {
         setState(() {
           _errorMessage = 'Login failed. Please check your credentials.';
         });
      }
    } on AuthException catch (e) {
       setState(() {
        _errorMessage = e.message;
       });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
         setState(() {
           _isLoading = false;
         });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView( // Added for smaller screens
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'NCDC City Manager Login',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50), // Make button wider
                        ),
                        child: const Text('Login'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 