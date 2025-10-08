// login_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appointment_system.dart';
import 'user_service.dart'; // <-- New import

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Instantiate user service
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// Loads saved email and password from shared preferences.
  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('saved_email');
    String? savedPassword = prefs.getString('saved_password');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
    if (savedPassword != null) {
      _passwordController.text = savedPassword;
    }
  }

  /// Saves the email and password to shared preferences.
  Future<void> _saveCredentials(String email, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
  }

  /// Validates and performs login using Firestore.
  void _validateAndLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Attempt login through Firestore
      final role = await _userService.loginUser(
        email: email,
        password: password,
      );

      if (role != null) {
        // If credentials are valid, save them locally for auto-fill
        _saveCredentials(email, password);

        // Navigate to AppointmentSystem, passing email + role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentSystem(
              loggedUserEmail: email,
              userRole: role, // <-- pass the role we got from Firestore
            ),
          ),
        );
      } else {
        // Display an error message if login fails.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Email Text Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Text Field
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
                const SizedBox(height: 24),
                // Login Button
                ElevatedButton(
                  onPressed: _validateAndLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
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