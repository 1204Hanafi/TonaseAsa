import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tonase_app/firebase_options.dart';
import 'layouts/coverpage.dart';
import 'layouts/loginpage.dart';
import 'layouts/forgotpasswordpage.dart';
import 'layouts/registrationpage.dart';
import 'layouts/homepage.dart';
import 'layouts/tonaseinputpage.dart';
import 'layouts/areapage.dart';
import 'layouts/customerpage.dart';
import 'layouts/dailyreportpage.dart';
import 'layouts/historitonasepage.dart';
import 'utils/file_saver.dart';
import 'utils/pdf_exporter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main({FileSaver? fileSaver, PdfExporter? pdfExporter}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TonaseApp(fileSaver: fileSaver, pdfExporter: pdfExporter));
}

class TonaseApp extends StatelessWidget {
  final FileSaver? fileSaver;
  final PdfExporter? pdfExporter;

  const TonaseApp({super.key, this.fileSaver, this.pdfExporter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tonase',
      theme: ThemeData(fontFamily: 'Poppins', primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const CoverPage(),
        '/login': (context) => const LoginPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/register': (context) => const RegistrationPage(),
        '/home': (context) => const HomePage(),
        '/input-tonase': (context) => const TonaseInputPage(),
        '/area': (context) => const AreaPage(),
        '/customer': (context) => const CustomerPage(),
        '/daily': (context) =>
            DailyReportPage(fileSaver: fileSaver, pdfExporter: pdfExporter),
        '/histori': (context) => HistoriTonasePage(),
      },
    );
  }
}
