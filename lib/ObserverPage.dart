import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ObserverPage extends StatefulWidget {
  const ObserverPage({Key? key}) : super(key: key);

  @override
  State<ObserverPage> createState() => _ObserverPageState();
}

class _ObserverPageState extends State<ObserverPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _addSupervisor() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showDialog('Veuillez remplir tous les champs.');
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _emailController.clear();
      _passwordController.clear();
      _showDialog('Superviseur ajouté dans Firebase Auth avec succès.');
    } on FirebaseAuthException catch (e) {
      _showDialog(e.message ?? 'Erreur lors de la création.');
    }
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter un superviseur'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email')),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Mot de passe'),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addSupervisor,
              child: Text('Créer le compte'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
