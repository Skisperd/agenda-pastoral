import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/auth/auth_service.dart';
import '../../data/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    _run(
      () => _signUp
          ? auth.signUpWithEmail(_name.text, _email.text, _password.text)
          : auth.signInWithEmail(_email.text, _password.text),
    );
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Digite seu e-mail para receber o link de redefinição.');
      return;
    }
    await _run(() => ref.read(authServiceProvider).sendPasswordReset(_email.text));
    if (mounted && _error == null) toast(context, 'Enviamos um link para ${_email.text.trim()}.');
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final demo = ref.watch(isDemoProvider);
    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppIcon(size: 96)),
                  const SizedBox(height: 22),
                  Text(
                    'PEDRAS VIVAS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: brandFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 40,
                      height: 1,
                      letterSpacing: 1.2,
                      color: context.isDark ? pal.label : Brand.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Igreja Cristã Presbiteriana Pedras Vivas',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 18, 40, 0),
                    child: Text(
                      '“Também vós mesmos, como pedras que vivem, sois edificados casa espiritual.”  1Pe 2.5',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (demo) ..._demo() else ..._form_(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _demo() => [
    Section(
      header: 'Entrar como',
      footer: 'Modo demonstração: dados de exemplo carregados no aparelho; nada é salvo.',
      children: [
        for (final r in AppRole.values.where((r) => r.isApproved))
          ListRow(
            leading: IconTile(r.symbol, color: r.tint),
            title: r.label,
            onTap: () => (ref.read(authServiceProvider) as DemoAuthService).signInAs(r),
          ),
      ],
    ),
  ];

  List<Widget> _form_() => [
    Form(
      key: _form,
      child: Section(
        children: [
          if (_signUp)
            FieldRow(
              controller: _name,
              placeholder: 'Nome',
              capitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().length < 2 ? 'Informe seu nome' : null,
            ),
          FieldRow(
            controller: _email,
            placeholder: 'E-mail',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v ?? '').contains('@') ? null : 'E-mail inválido',
          ),
          FieldRow(
            controller: _password,
            placeholder: 'Senha',
            obscure: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            validator: (v) => (v ?? '').length < 6 ? 'Mínimo de 6 caracteres' : null,
          ),
        ],
      ),
    ),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pal.red, fontSize: 14),
        ),
      ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: PrimaryButton(label: _signUp ? 'Criar conta' : 'Entrar', loading: _busy, onPressed: _submit),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: _GoogleButton(onPressed: _busy ? null : () => _run(ref.read(authServiceProvider).signInWithGoogle)),
    ),
    const SizedBox(height: 14),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NavAction(
          label: _signUp ? 'Já tenho conta' : 'Criar conta',
          onPressed: () => setState(() => _signUp = !_signUp),
        ),
        if (!_signUp) ...[
          Text('   ·   ', style: TextStyle(color: context.pal.tertiaryLabel)),
          NavAction(label: 'Esqueci a senha', onPressed: _busy ? null : _reset),
        ],
      ],
    ),
  ];
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tappable(
    onTap: onPressed,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.pal.separator),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'G',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4), height: 1),
          ),
          const SizedBox(width: 10),
          Text('Continuar com Google', style: context.text.labelLarge),
        ],
      ),
    ),
  );
}
