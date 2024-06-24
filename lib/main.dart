import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  TextEditingController _inputController = TextEditingController();
  List<String> _translations = [];
  GoogleTranslator translator = GoogleTranslator();
  List<String> selectedLanguages = ['es', 'fr']; // default languages

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
              decoration: InputDecoration(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
