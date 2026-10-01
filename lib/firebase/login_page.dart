import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Login por e-mail e senha (gratuito, funciona em Android, iOS e web sem
/// configuração extra).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      if (_creating) {
        await _auth.createUserWithEmailAndPassword(email: email, password: _password.text);
      } else {
        await _auth.signInWithEmailAndPassword(email: email, password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      _show(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _show('Digite seu e-mail acima para receber o link de nova senha.');
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _show('Enviamos um link para $email.');
    } on FirebaseAuthException catch (e) {
      _show(_message(e));
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'E-mail inválido.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'E-mail ou senha incorretos.',
    'email-already-in-use' => 'Já existe uma conta com esse e-mail. Use "Entrar".',
    'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
    'too-many-requests' => 'Muitas tentativas. Aguarde alguns minutos.',
    'network-request-failed' => 'Sem conexão com a internet.',
    _ => 'Não foi possível entrar (${e.code}).',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Icon(
                    Icons.church_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text('Agenda Pastoral', style: text.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('campoEmail'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').contains('@') ? null : 'Digite um e-mail válido',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('campoSenha'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').length >= 6 ? null : 'Mínimo de 6 caracteres',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('botaoEntrar'),
                    onPressed: _busy ? null : _submit,
                    child: Text(_creating ? 'Criar conta' : 'Entrar'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _creating = !_creating),
                    child: Text(_creating ? 'Já tenho conta' : 'Primeiro acesso? Criar conta'),
                  ),
                  if (!_creating)
                    TextButton(onPressed: _resetPassword, child: const Text('Esqueci a senha')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
