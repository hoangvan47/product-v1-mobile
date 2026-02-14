import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

const miniAppBaseUrl = String.fromEnvironment(
  'MINI_APP_URL',
  defaultValue: 'http://127.0.0.1:5173',
);

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

void main() {
  runApp(const MiniAppHost());
}

class MiniAppHost extends StatelessWidget {
  const MiniAppHost({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Commerce Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
      ),
      home: const AppRootPage(),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.email,
    required this.accessToken,
    required this.refreshToken,
  });

  final String email;
  final String accessToken;
  final String refreshToken;

  Map<String, String> toStorage() => {
    'email': email,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  static AuthSession? fromStorage(Map<String, String?> values) {
    final email = values['email'];
    final accessToken = values['accessToken'];
    final refreshToken = values['refreshToken'];
    if (
        email == null ||
        email.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return AuthSession(
      email: email,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class AuthStorage {
  static const _emailKey = 'auth_email';
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  Future<AuthSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthSession.fromStorage({
      'email': prefs.getString(_emailKey),
      'accessToken': prefs.getString(_accessTokenKey),
      'refreshToken': prefs.getString(_refreshTokenKey),
    });
  }

  Future<void> save(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, session.email);
    await prefs.setString(_accessTokenKey, session.accessToken);
    await prefs.setString(_refreshTokenKey, session.refreshToken);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}

class AuthApi {
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final message = data['message'];
      if (message is String) {
        throw Exception(message);
      }
      if (message is List && message.isNotEmpty) {
        throw Exception(message.first.toString());
      }
      throw Exception('Đăng nhập thất bại');
    }

    final user = data['user'] as Map<String, dynamic>? ?? {};
    final responseEmail = user['email']?.toString() ?? email;
    final accessToken = data['accessToken']?.toString();
    final refreshToken = data['refreshToken']?.toString();
    if (accessToken == null || refreshToken == null) {
      throw Exception('Thiếu token từ máy chủ');
    }

    return AuthSession(
      email: responseEmail,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class AppRootPage extends StatefulWidget {
  const AppRootPage({super.key});

  @override
  State<AppRootPage> createState() => _AppRootPageState();
}

class _AppRootPageState extends State<AppRootPage> {
  final _storage = AuthStorage();
  final _api = AuthApi();
  AuthSession? _session;
  bool _isBooting = true;

  @override
  void initState() {
    super.initState();
    _hydrateSession();
  }

  Future<void> _hydrateSession() async {
    final session = await _storage.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _isBooting = false;
    });
  }

  Future<void> _login(String email, String password) async {
    final session = await _api.login(email: email, password: password);
    await _storage.save(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _logout() async {
    await _storage.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBooting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return LoginPage(onLogin: _login);
    }

    return DashboardPage(
      session: _session!,
      onLogout: _logout,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLogin, super.key});

  final Future<void> Function(String email, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'demo@shop.local');
  final _passwordController = TextEditingController(text: '123456');
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Commerce Mobile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng nhập để tham gia hoặc điều phối livestream.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty || !text.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').length < 6) {
                            return 'Mật khẩu tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Đăng nhập'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.session,
    required this.onLogout,
    super.key,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _roomController = TextEditingController();
  int _tabIndex = 0;

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  String _buildMiniAppUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = miniAppBaseUrl.endsWith('/') ? miniAppBaseUrl.substring(0, miniAppBaseUrl.length - 1) : miniAppBaseUrl;
    final safePath = path.startsWith('/') ? path : '/$path';
    return '$base$safePath';
  }

  void _openLive(String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveWebViewPage(
          title: title,
          url: _buildMiniAppUrl(path),
        ),
      ),
    );
  }

  void _openJoinOrHost({required bool isHost}) {
    final roomId = _roomController.text.trim();
    if (roomId.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Room ID hợp lệ')),
      );
      return;
    }
    final route = isHost ? '/host-room/$roomId' : '/join-room/$roomId';
    _openLive(isHost ? 'Host livestream' : 'Xem livestream', route);
  }

  Future<void> _performLogout() async {
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thao tác livestream', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Nhập Room ID để join hoặc host như luồng web hiện tại.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room ID',
                      hintText: 'Ví dụ: ls-ag1ve8-mlj8vaph',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openJoinOrHost(isHost: false),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Join live'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openJoinOrHost(isHost: true),
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Host live'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Mở trang bán hàng'),
              subtitle: const Text('Trang chính Framer/React trên mini app'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openLive('Trang bán hàng', '/'),
            ),
          ),
        ],
      ),
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tài khoản', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('Email: ${widget.session.email}'),
                  const SizedBox(height: 8),
                  Text(
                    'Token: ${widget.session.accessToken.substring(0, widget.session.accessToken.length > 24 ? 24 : widget.session.accessToken.length)}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _performLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Commerce'),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), label: 'Livestream'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class LiveWebViewPage extends StatefulWidget {
  const LiveWebViewPage({
    required this.title,
    required this.url,
    super.key,
  });

  final String title;
  final String url;

  @override
  State<LiveWebViewPage> createState() => _LiveWebViewPageState();
}

class _LiveWebViewPageState extends State<LiveWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _lastWebMessage = 'Chưa có phản hồi';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _sendToWeb(
              type: 'flutter_ready',
              payload: {
                'platform': defaultTargetPlatform.name,
                'miniApp': 'product_v1_mobile',
                'page': widget.title,
              },
            );
          },
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() => _lastWebMessage = message.message);
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _sendToWeb({
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    final data = jsonEncode({
      'source': 'flutter',
      'type': type,
      'payload': payload ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    });
    final escapedData = jsonEncode(data);
    await _controller.runJavaScript(
      'window.receiveFromFlutter && window.receiveFromFlutter($escapedData);',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Gửi ping sang web',
            onPressed: () {
              _sendToWeb(
                type: 'ping_from_flutter',
                payload: {'message': 'Ping từ mobile'},
              );
            },
            icon: const Icon(Icons.send_outlined),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            width: double.infinity,
            color: const Color(0xFFF2F2F2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              'Web gửi về Flutter: $_lastWebMessage',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
