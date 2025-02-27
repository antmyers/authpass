import 'dart:math';

import 'package:authpass/bloc/app_data.dart';
import 'package:authpass/ui/widgets/primary_button.dart';
import 'package:authpass/ui/widgets/slide_hide_widget.dart';
import 'package:authpass/utils/extension_methods.dart';
import 'package:authpass/utils/password_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quiver/iterables.dart' as iterables;

enum FinishButtonStyle {
  done,
  save,
}

class PasswordGeneratorScreen extends StatelessWidget {
  const PasswordGeneratorScreen({Key key, this.finishButton}) : super(key: key);

  static Route<String> route({@required FinishButtonStyle finishButton}) =>
      MaterialPageRoute(
        settings: const RouteSettings(name: '/passwordGenerator'),
        builder: (context) => PasswordGeneratorScreen(
          finishButton: finishButton,
        ),
      );

  /// Either a 'Done' for using in a form field, or 'Save as Default'
  final FinishButtonStyle finishButton;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.generatePassword),
      ),
      body: GeneratePassword(
        doneButtonLabel: finishButton == FinishButtonStyle.done
            ? loc.doneButtonLabel
            : loc.useAsDefault,
        doneButtonOnPressed: (password) => Navigator.of(context).pop(password),
      ),
    );
  }
}

class GeneratePassword extends StatefulWidget {
  const GeneratePassword({
    Key key,
    this.doneButtonIcon,
    @required this.doneButtonLabel,
    this.doneButtonOnPressed,
  })  : assert(doneButtonLabel != null),
        super(key: key);

  final Icon doneButtonIcon;
  final String doneButtonLabel;
  final void Function(String password) doneButtonOnPressed;

  @override
  _GeneratePasswordState createState() => _GeneratePasswordState();
}

class _GeneratePasswordState extends State<GeneratePassword>
    with SingleTickerProviderStateMixin {
  static Map<String, CharacterSet> characterSets(AppLocalizations loc) => {
        loc.characterSetLowerCase: CharacterSet.alphabetAsciiLowerCase,
        loc.characterSetUpperCase: CharacterSet.alphabetAsciiUpperCase,
        loc.characterSetNumeric: CharacterSet.numeric,
        loc.characterSetUmlauts: CharacterSet.alphabetUmlauts,
        loc.characterSetSpecial: CharacterSet.specialCharacters,
      };

  Map<String, CharacterSet> _characterSets;

  static const _defaultCharacterSets = {
    CharacterSet.alphabetAsciiLowerCase,
    CharacterSet.alphabetAsciiUpperCase,
    CharacterSet.numeric,
  };

  static const int passwordLengthMin = 5;
  static const int passwordLengthMax = 40;

  /// prevent people from crashing the app.
  static const int passwordLengthCustomMax = 10000;

  final Set<CharacterSet> _selectedCharacterSet = Set.of(_defaultCharacterSets);

  String _password;
  int _passwordLength = 20;
  final _passwordLengthCustom = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appData = Provider.of<AppData>(context);
    _passwordLength = appData.passwordGeneratorLength ?? _passwordLength;
    if (appData.passwordGeneratorCharacterSets.isNotEmpty) {
      _selectedCharacterSet
        ..clear()
        ..addAll(CharacterSet.characterSetFromIds(
            appData.passwordGeneratorCharacterSets));
    }
    _characterSets = characterSets(AppLocalizations.of(context));
    _generatePassword();
  }

  void _generatePassword() {
    setState(() {
      _password = PasswordGenerator.singleton().generatePassword(
          CharacterSetCollection(_selectedCharacterSet.toList()),
          _passwordLength);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _password));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar(reason: SnackBarClosedReason.remove)
                    ..showSnackBar(
                        SnackBar(content: Text(loc.copiedToClipboard)));
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: loc.generatorPassword,
                    suffixIcon: const Icon(Icons.content_copy),
                    // contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 20),
                    // alignLabelWithHint: true,
                    hintMaxLines: 1,
                    // isDense: true,
                  ),
                  child: Text(
                    _password,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            SimpleGridWidget(
              children: _characterSets.entries
                  .map<Widget>(
                    (entry) => OptionToggleTile(
                      label: entry.key.replaceFirst(' (', '\n('), // NON-NLS
                      value: _selectedCharacterSet.contains(entry.value),
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _selectedCharacterSet.add(entry.value);
                          } else {
                            _selectedCharacterSet.remove(entry.value);
                          }
                          _generatePassword();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: <Widget>[
                const SizedBox(width: 16),
                Text(loc.length),
                Expanded(
                  child: Slider(
                    value: min(_passwordLength.toDouble(),
                        passwordLengthMax.toDouble()),
                    min: passwordLengthMin.toDouble(),
                    max: passwordLengthMax.toDouble(),
                    divisions: (passwordLengthMax - passwordLengthMin),
                    label: _passwordLength.toString(),
                    onChanged: (val) {
                      setState(() {
                        _passwordLength = val.round();
                        _generatePassword();
                        if (_passwordLength == passwordLengthMax &&
                            _passwordLengthCustom.text.isEmpty) {
                          _passwordLengthCustom.text =
                              passwordLengthMax.toString();
                        }
                      });
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 32),
                  child: Text(_passwordLength.toString()),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SlideHideWidget(
              hide: _passwordLength < passwordLengthMax.toDouble(),
              vsync: this,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: TextField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      labelText: loc.customLength,
                      helperText: loc.customLengthHelperText(passwordLengthMax),
                    ),
                    controller: _passwordLengthCustom,
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    onChanged: (value) {
                      int.tryParse(value)?.let((number) {
                        if (number > passwordLengthMax &&
                            number <= passwordLengthCustomMax) {
                          setState(() {
                            _passwordLength = number;
                            _generatePassword();
                          });
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            ...?(widget.doneButtonOnPressed == null
                ? null
                : [
                    Center(
                      child: PrimaryButton(
                        onPressed: () {
                          final appDataBloc =
                              Provider.of<AppDataBloc>(context, listen: false);
                          appDataBloc.update((b, appData) => b
                            ..passwordGeneratorLength = _passwordLength
                            ..passwordGeneratorCharacterSets.replace(
                                _selectedCharacterSet.map<String>((set) =>
                                    CharacterSet.characterSetIdFor(set))));
                          widget.doneButtonOnPressed(_password);
                        },
                        icon: widget.doneButtonIcon ??
                            const Icon(Icons.check_circle_outline),
                        large: false,
                        child: Text(widget.doneButtonLabel),
                      ),
                    )
                  ]),
          ],
        ),
      ),
    );
  }
}

class SimpleGridWidget extends StatelessWidget {
  const SimpleGridWidget({
    Key key,
    this.columns = 2,
    @required this.children,
  })  : assert(children != null),
        super(key: key);

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: iterables
            .partition(
                children.followedBy(List.generate(
                    children.length % columns, (_) => Container())),
                columns)
            .map((partition) => Row(
                  mainAxisSize: MainAxisSize.max,
                  children:
                      partition.map((child) => Expanded(child: child)).toList(),
                ))
            .toList());
  }
}

class OptionToggleTile extends StatelessWidget {
  const OptionToggleTile({
    Key key,
    @required this.label,
    @required this.value,
    @required this.onChanged,
  })  : assert(label != null),
        assert(value != null),
        assert(onChanged != null),
        super(key: key);

  final String label;
  final bool value;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: onChanged),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.subtitle1),
            ),
            // Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
