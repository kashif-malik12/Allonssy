import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      usePathUrlStrategy();
    }

    final releaseAndroidWorkaround =
        !kIsWeb && kReleaseMode && defaultTargetPlatform == TargetPlatform.android;
    final authStorage = releaseAndroidWorkaround
        ? _FileLocalStorage(
            persistSessionKey:
                'sb-${Uri.parse(Env.supabaseUrl).host.split(".").first}-auth-token',
          )
        : null;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: releaseAndroidWorkaround
          ? FlutterAuthClientOptions(
              localStorage: authStorage,
              pkceAsyncStorage: _FileGotrueAsyncStorage(),
            )
          : const FlutterAuthClientOptions(),
    );

    runApp(const ProviderScope(child: App()));
  } catch (error, stackTrace) {
    runApp(_StartupErrorApp(error: error, stackTrace: stackTrace));
  }
}

class _FileLocalStorage extends LocalStorage {
  _FileLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  late final File _file = File('${Directory.systemTemp.path}\\$persistSessionKey.json');

  @override
  Future<void> initialize() async {
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
  }

  @override
  Future<String?> accessToken() async {
    if (!await _file.exists()) return null;
    return _file.readAsString();
  }

  @override
  Future<bool> hasAccessToken() async => _file.exists();

  @override
  Future<void> persistSession(String persistSessionString) async {
    await initialize();
    await _file.writeAsString(persistSessionString, flush: true);
  }

  @override
  Future<void> removePersistedSession() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

class _FileGotrueAsyncStorage extends GotrueAsyncStorage {
  const _FileGotrueAsyncStorage();

  File _fileForKey(String key) => File('${Directory.systemTemp.path}\\gotrue_$key.txt');

  @override
  Future<String?> getItem({required String key}) async {
    final file = _fileForKey(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> removeItem({required String key}) async {
    final file = _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    final file = _fileForKey(key);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(value, flush: true);
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F1E8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFF12211D)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Startup failed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(error.toString()),
                    const SizedBox(height: 16),
                    Text(
                      stackTrace.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
