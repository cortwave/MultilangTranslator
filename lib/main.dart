import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multiple languages translator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _inputController = TextEditingController();
  final Uri _githubUrl = Uri.parse('https://github.com/cortwave/MultilangTranslator');
  List<String> _translations = [];
  GoogleTranslator translator = GoogleTranslator();
  FlutterTts flutterTts = FlutterTts();
  List<String> selectedLanguages = ['lt', 'pl', 'he', 'en', 'be']; // default languages

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguages();
  }

  Future<void> _loadSelectedLanguages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedLanguages = prefs.getStringList('selectedLanguages');
    if (savedLanguages != null) {
      setState(() {
        selectedLanguages = savedLanguages;
      });
    }
  }

  Future<void> _speak(String lang, String text) async {
    await flutterTts.setLanguage(lang); // Set the language for TTS
    await flutterTts.setPitch(1.0); // Set the pitch for TTS
    await flutterTts.speak(text); // Speak the text
  }

  Future<void> _saveSelectedLanguages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedLanguages', selectedLanguages);
  }

  void _updateOutput() {
    setState(() {
      _translations = List.generate(selectedLanguages.length, (index) => 'Translating...');
    });

    for (int i = 0; i < selectedLanguages.length; i++) {
      translator.translate(_inputController.text, to: selectedLanguages[i]).then((result) {
        setState(() {
          _translations[i] = result.text;
        });
      }).catchError((error) {
        print("Translation error for ${selectedLanguages[i]}: $error");
        setState(() {
          _translations[i] = 'Error translating to ${selectedLanguages[i]}';
        });
      });
    }
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage(selectedLanguages: selectedLanguages)),
    );

    if (result != null) {
      setState(() {
        selectedLanguages = result;
        _saveSelectedLanguages();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiple languages translator'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'Enter text',
              ),
              onSubmitted: (value) {
                _updateOutput();
              }
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateOutput,
              child: Text('Translate'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _translations.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('${availableLanguages[selectedLanguages[index]]}'),
                    subtitle: SelectableText(_translations[index]),
                    trailing: IconButton(
                      icon: Icon(Icons.volume_up),
                      onPressed: () => _speak(selectedLanguages[index] ,_translations[index]),
                    ),
                  );
                },
              ),
            ),
            Divider(), // To separate the content from the footer
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Source code: '),
                InkWell(
                  onTap: () => launchUrl(_githubUrl),
                  child: Text(
                    'MultilangTranslator on GitHub',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
