import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_auth_service.dart';
import 'screens/supabase_login_screen.dart';

// Your Supabase project credentials
const String SUPABASE_URL = 'https://bzugvwthyycszhohetlc.supabase.co';
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6dWd2d3RoeXljc3pob2hldGxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMDQyNTQsImV4cCI6MjA2OTg4MDI1NH0.CIluaTZ6sgEugrsftY6iCVyXXoqOFH-vUOi3Rh_vAfc';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseAuthService.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vietnamese Lottery OCR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final SupabaseAuthService _authService = SupabaseAuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data?.session != null) {
          return MainAppScreen();
        } else {
          return SupabaseLoginScreen();
        }
      },
    );
  }
}

class MainAppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vietnamese Lottery OCR'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'profile') {
                _showProfileDialog(context);
              } else if (value == 'logout') {
                await SupabaseAuthService().signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            SizedBox(height: 24),
            Text(
              '🎉 Supabase Authentication Working!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Supabase authentication is successfully integrated.\nYour OCR features are ready to be re-enabled!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 32),
            Text(
              '✅ Apple Sign In\n✅ Google Sign In\n✅ Phone Authentication\n✅ No iOS build issues!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userData = SupabaseAuthService().getUserData();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userData?['full_name'] != null) ...[
              Text('Name: ${userData!['full_name']}'),
              const SizedBox(height: 8),
            ],
            if (userData?['email'] != null) ...[
              Text('Email: ${userData!['email']}'),
              const SizedBox(height: 8),
            ],
            if (userData?['phone'] != null) ...[
              Text('Phone: ${userData!['phone']}'),
              const SizedBox(height: 8),
            ],
            Text('User ID: ${user?.id.substring(0, 8)}...'),
            const SizedBox(height: 8),
            Text('Account created: ${user?.createdAt.toString().split('T')[0] ?? 'Unknown'}'),
            const SizedBox(height: 12),
            Text(
              'Provider: ${userData?['provider'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '✅ Powered by Supabase',
                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}