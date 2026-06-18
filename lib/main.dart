import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Drop the `/#/` hash from web URLs (e.g. `/needs-attention` instead of
  // `/#/needs-attention`). Deep links resolve on refresh because Firebase
  // Hosting rewrites all paths to index.html (see firebase.json).
  if (kIsWeb) usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: TurboBoardApp()));
}
