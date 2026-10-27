import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'format.dart';
import 'widgets.dart';

/// Abre o WhatsApp com a conversa de [phone] (e a mensagem, se houver).
Future<void> openWhatsApp(BuildContext context, String phone, {String? text}) async {
  final d = phoneDigits(phone);
  if (d == null) return toast(context, 'Telefone inválido.');
  final uri = Uri.https('wa.me', '/$d', {'text': ?text});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    toast(context, 'Não foi possível abrir o WhatsApp.');
  }
}

Future<void> callPhone(BuildContext context, String phone) async {
  final d = phoneDigits(phone);
  if (d == null) return toast(context, 'Telefone inválido.');
  if (!await launchUrl(Uri(scheme: 'tel', path: '+$d')) && context.mounted) {
    await Clipboard.setData(ClipboardData(text: fmtPhone(phone)));
    if (context.mounted) toast(context, 'Número copiado: ${fmtPhone(phone)}');
  }
}

Future<void> sendEmail(BuildContext context, String email) async {
  if (!await launchUrl(Uri(scheme: 'mailto', path: email)) && context.mounted) {
    await Clipboard.setData(ClipboardData(text: email));
    if (context.mounted) toast(context, 'E-mail copiado: $email');
  }
}

/// Copia um texto pronto para colar no WhatsApp (escala, programação).
Future<void> copyForWhatsApp(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copiado. É só colar no WhatsApp.');
}

/// Pergunta se quer enviar pelo WhatsApp ou copiar.
Future<void> shareText(BuildContext context, String text) async {
  final choice = await showActionSheet<int>(
    context,
    title: 'Compartilhar',
    actions: const [SheetAction('Enviar pelo WhatsApp', 0), SheetAction('Copiar texto', 1)],
  );
  if (!context.mounted || choice == null) return;
  if (choice == 1) return copyForWhatsApp(context, text);
  final uri = Uri.https('wa.me', '/', {'text': text});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    await copyForWhatsApp(context, text);
  }
}
