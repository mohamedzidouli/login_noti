import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:crypto/crypto.dart';

void main() {
  runApp(MaterialApp(
    home: LoginPage(),
  ));
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String message = '';

  @override
  void initState() {
    super.initState();
    checkLoggedIn();
  }

  Future<void> checkLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final url = prefs.getString('decodedUrl') ?? '';
      final email = prefs.getString('email') ?? '';

      navigateToWebView(url, email);
    }
  }

  Future<void> login() async {
    final url = Uri.parse('https://telusholding.cloud/Mobile_test/fetch2.php');

    final hashedPassword = hashPassword(passwordController.text);

    final response = await http.post(
      url,
      body: {
        'email': emailController.text,
        'passwd': hashPassword(passwordController.text),
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String urlEncoded = data['url'];
      String decodedUrl = Uri.decodeComponent(urlEncoded);
      String messageFromApi = data['message'];

      if (messageFromApi == 'OK') {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('isLoggedIn', true); // Marquez l'utilisateur comme connecté
        prefs.setString('decodedUrl', decodedUrl); // Enregistrez le decodedUrl
        prefs.setString('email', emailController.text); // Enregistrez l'e-mail
        navigateToWebView(decodedUrl, emailController.text);
      } else {
        setState(() {
          message = messageFromApi;
        });
      }
    } else {
      setState(() {
        message = 'Une erreur s\'est produite';
      });
    }
  }

  String hashPassword(String password) {
    final salt = "telus";
    final bytes = utf8.encode(password + salt);
    final hashedBytes = sha256.convert(bytes);
    return hashedBytes.toString();
  }

  void navigateToWebView(String url, String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(url: url, email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Mot de passe'),
            ),
            SizedBox(height: 20),
            Text('Données à envoyer : ${{
              'email': emailController.text,
              'passwd': hashPassword(passwordController.text),
            }}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: login,
              child: Text('Se connecter'),
            ),
            SizedBox(height: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final String email;

  WebViewPage({required this.url, required this.email});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late WebViewController _webViewController;
  Timer? _logoutTimer;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    startLogoutTimer();
    Timer.periodic(Duration(seconds: 10), (timer) {
      fetchNotifications();
    });
  }

  void startLogoutTimer() {
    const logoutTimeInSeconds = 300; // 5 minutes
    _logoutTimer = Timer(Duration(seconds: logoutTimeInSeconds), () {
      logout();
    });
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLoggedIn', false);
    _logoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ),
    );
  }

  Future<void> fetchNotifications() async {
    final url = Uri.parse('https://telusholding.cloud/Mobile_test/notif.php');
    final response = await http.post(
      url,
      body: {
        'email': widget.email,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final message = data['message'];

      showNotification(message);
    }
  }

  Future<void> showNotification(String message) async {
    if (message != "vide") {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
      const platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Nouvelle notification',
        message,
        platformChannelSpecifics,
        payload: 'notification_payload',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebView'),
      ),
      body: WebView(
        initialUrl: widget.url,
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        onWebResourceError: (error) {
          print('WebView Error: ${error.toString()}');
        },
      ),
    );
  }
}
