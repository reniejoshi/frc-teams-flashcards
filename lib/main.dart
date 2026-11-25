import 'package:frc_teams_flashcards/app_colors.dart';
import 'package:frc_teams_flashcards/team_api.dart';
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
  final TeamApi _teamApi = TeamApi.fromEnvironment();
  Team? _team;
  String? _error;
  bool _isLoading = true;
  Color _borderColor = AppColors.accent;

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _teamApi.close();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
        _borderColor = AppColors.accent;
        _answerController.clear();
      });
    }

    try {
      final team = await _teamApi.fetchRandomTeam();
      if (!mounted) return;
      setState(() {
        _team = team;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _checkAnswer() {
    final team = _team;
    if (team == null) return;

    setState(() {
      _borderColor =
          _answerController.text.trim().toLowerCase() ==
              team.nickname.trim().toLowerCase()
          ? AppColors.correct
          : AppColors.incorrect;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadTeam,
            tooltip: 'Load random team',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                        if (_isLoading) ...[
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('Loading team...'),
                        ] else if (_error != null) ...[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ] else if (_team != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${_team!.number}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 40),
                          TextField(
                            controller: _answerController,
                            onSubmitted: (_) => _checkAnswer(),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
