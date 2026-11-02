import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_background.dart';
import 'widgets/dramatic_transitions.dart';

const supabaseUrl = 'https://lwzhulqhjioecqlwasdl.supabase.co';
const supabaseAnonKey = 'sb_publishable_dRWM_lwncSiOBvIcb8XLOw_sZ2iCtoF';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: supabaseAnonKey,
  );

  runApp(const LostAndFoundApp());
}

class LostAndFoundApp extends StatelessWidget {
  const LostAndFoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUT Lost & Found',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B2FE0),
          brightness: Brightness.dark, // white text/icons on the dark background
        ),
        // Transparent so the global background shows through every screen
        scaffoldBackgroundColor: Colors.transparent,
        // Cinematic transition for every screen change
        pageTransitionsTheme: dramaticPageTransitions,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      // Draws bhp.jpeg behind every screen
      builder: (context, child) => AppBackground(child: child),
      home: const SplashGate(),
    );
  }
}

/// Plays the opening splash, then reveals the app underneath it.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _revealed = false; // app is built underneath the fading splash
  bool _done = false; // splash can be removed

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_revealed) const AuthGate(key: ValueKey('app')),
        if (!_done)
          SplashScreen(
            key: const ValueKey('splash'),
            onReveal: () => setState(() => _revealed = true),
            onDone: () => setState(() => _done = true),
          ),
      ],
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        // Signing in/out cross-fades with a gentle zoom instead of snapping
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: session != null
              ? const HomeScreen(key: ValueKey('home'))
              : const WelcomeScreen(key: ValueKey('welcome')),
        );
      },
    );
  }
}
