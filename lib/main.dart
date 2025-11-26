import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dropdown_search/dropdown_search.dart';
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
  final Uri _githubUrl =
      Uri.parse('https://github.com/cortwave/MultilangTranslator');
  List<String> _translations = [];
  GoogleTranslator translator = GoogleTranslator();
  FlutterTts flutterTts = FlutterTts();
  List<String> selectedLanguages = [
    'lt',
    'pl',
    'he',
    'en',
    'be'
  ]; // default languages
  String? _sourceLanguage; // null means auto-detect
  String? _detectedLanguage; // stores detected language when in auto-detect mode
  static const String _autoDetectValue = '__AUTO_DETECT__';

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguages();
    _loadSourceLanguage();
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

  Future<void> _loadSourceLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSourceLanguage = prefs.getString('sourceLanguage');
    setState(() {
      // Convert empty string or null to null (auto-detect)
      _sourceLanguage = (savedSourceLanguage == null || savedSourceLanguage.isEmpty) 
          ? null 
          : savedSourceLanguage;
    });
  }

  Future<void> _saveSourceLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_sourceLanguage == null) {
      await prefs.remove('sourceLanguage');
    } else {
      await prefs.setString('sourceLanguage', _sourceLanguage!);
    }
  }

  // Convert internal null (auto-detect) to display value
  String? _getDisplayValue() {
    return _sourceLanguage ?? _autoDetectValue;
  }

  // Convert display value back to internal value
  String? _getInternalValue(String? displayValue) {
    if (displayValue == _autoDetectValue) return null;
    return displayValue;
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
      _translations =
          List.generate(selectedLanguages.length, (index) => 'Translating...');
      _detectedLanguage = null; // Reset detected language
    });

    for (int i = 0; i < selectedLanguages.length; i++) {
      // Build translation request with optional from parameter
      final translationFuture = _sourceLanguage == null
          ? translator.translate(_inputController.text, to: selectedLanguages[i])
          : translator.translate(_inputController.text,
              from: _sourceLanguage!, to: selectedLanguages[i]);

      translationFuture.then((result) {
        setState(() {
          _translations[i] = result.text;
          // Store detected language if in auto-detect mode and this is the first translation
          if (_sourceLanguage == null && _detectedLanguage == null && i == 0) {
            _detectedLanguage = result.sourceLanguage.code;
          }
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
      MaterialPageRoute(
          builder: (context) =>
              SettingsPage(selectedLanguages: selectedLanguages)),
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
        title: const Text('Multiple languages translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
                }),
            const SizedBox(height: 16),
            // Source language dropdown with search
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 300,
                child: DropdownSearch<String>(
                  selectedItem: _getDisplayValue(),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search language...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  items: [
                    _autoDetectValue,
                    ...availableLanguages.entries.map((entry) => entry.key).toList(),
                  ],
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Translate from',
                      border: OutlineInputBorder(),
                      hintText: 'Auto-detect',
                    ),
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _sourceLanguage = _getInternalValue(newValue);
                      _detectedLanguage = null; // Reset detected language when changing source
                    });
                    _saveSourceLanguage();
                  },
                  itemAsString: (String? item) {
                    if (item == null || item == _autoDetectValue) return 'Auto-detect';
                    return availableLanguages[item] ?? item;
                  },
                  filterFn: (String? item, String? filter) {
                    if (item == null) return false;
                    if (item == _autoDetectValue) {
                      return 'auto-detect'.toLowerCase().contains(filter?.toLowerCase() ?? '');
                    }
                    final languageName = availableLanguages[item] ?? '';
                    final languageCode = item.toLowerCase();
                    return languageName.toLowerCase().contains(filter?.toLowerCase() ?? '') ||
                           languageCode.contains(filter?.toLowerCase() ?? '');
                  },
                  compareFn: (String? item1, String? item2) {
                    return item1 == item2;
                  },
                ),
              ),
            ),
            // Show detected language when in auto-detect mode
            if (_sourceLanguage == null && _detectedLanguage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Detected language: ${availableLanguages[_detectedLanguage] ?? _detectedLanguage}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateOutput,
              child: const Text('Translate'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _translations.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title:
                        Text('${availableLanguages[selectedLanguages[index]]}'),
                    subtitle: SelectableText(_translations[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => _speak(
                          selectedLanguages[index], _translations[index]),
                    ),
                  );
                },
              ),
            ),
            const Divider(), // To separate the content from the footer
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Source code: '),
                  InkWell(
                    onTap: () => launchUrl(_githubUrl),
                    child: const Text(
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
