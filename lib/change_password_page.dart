// change_password_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class ChangePasswordPage extends StatefulWidget {
  final String userEmail;

  const ChangePasswordPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;

  /// This function:
  /// 1. Looks up the user doc by email in Firestore
  /// 2. Validates the old password by checking it against the stored bcrypt hash
  /// 3. Verifies the new passwords match
  /// 4. Hashes the new password and updates Firestore
  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Query the user doc by email
      final querySnapshot = await _firestore
          .collection('Users')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      // Check if user doc is found
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'User not found in Firestore.';
          _isLoading = false;
        });
        return;
      }

      final userDoc = querySnapshot.docs.first;
      // Attempt to read the hashed password from the doc. If not found, it returns empty string.
      final String hashedPassword = userDoc.get('hashedPassword') ?? '';

      // Compare old password with the existing bcrypt hash
      final bool validOldPassword = BCrypt.checkpw(
        _oldPasswordController.text.trim(),
        hashedPassword,
      );
      if (!validOldPassword) {
        setState(() {
          _errorMessage = 'Old password is incorrect.';
          _isLoading = false;
        });
        return;
      }

      // Check if new password fields match
      if (_newPasswordController.text.trim() !=
          _confirmNewPasswordController.text.trim()) {
        setState(() {
          _errorMessage = 'New passwords do not match.';
          _isLoading = false;
        });
        return;
      }

      // Hash the new password
      final newHashedPassword = BCrypt.hashpw(
        _newPasswordController.text.trim(),
        BCrypt.gensalt(),
      );

      // Update the user document in Firestore
      await _firestore.collection('Users').doc(userDoc.id).update({
        'hashedPassword': newHashedPassword,
      });

      // On success, show a message and pop back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error changing password: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // If there's an error message, show it
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 10),
              ],
              // Old Password field
              TextFormField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Old Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your old password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // New Password field
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your new password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Confirm New Password field
              TextFormField(
                controller: _confirmNewPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please confirm your new password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Change Password Button
              ElevatedButton(
                onPressed: _isLoading
                    ? null // Disable the button while loading
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _changePassword();
                        }
                      },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Change Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}