import 'package:frc_teams_flashcards/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: AppColors.background,
          secondary: AppColors.secondary,
          onSecondary: AppColors.background,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          scrim: AppColors.overlay,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const MyHomePage(title: 'FRC Teams Flashcards'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _answerController = TextEditingController();
  late String _answer;
  Color _borderColor = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 300,
                ),
                child: GestureDetector(
                  onTap: () {
                    // Toggle front/back state here
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF263844),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          '2046',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _answerController,
                          onSubmitted: (_) {
                            setState(() {
                              _answer = _answerController.text
                                  .trim()
                                  .toLowerCase();
                              if (_answer == 'bear metal') {
                                _borderColor = AppColors.correct;
                              } else {
                                _borderColor = AppColors.incorrect;
                              }
                            });
                          },
                          decoration: InputDecoration(
                            fillColor: Colors.transparent,
                            filled: true,
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _borderColor,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _borderColor,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _borderColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            onPressed: () {},
            backgroundColor: AppColors.correct,
            child: const Icon(Icons.check_sharp),
          ),
          FloatingActionButton(
            onPressed: () {},
            backgroundColor: AppColors.incorrect,
            child: const Icon(Icons.close_sharp),
          ),
        ],
      ),
    );
  }
}
