import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/masters.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📅 Bienvenue')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sélectionnez le ou les masters dont vous voulez suivre le calendrier :',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.5,
                ),
                itemCount: masters.length,
                itemBuilder: (context, index) {
                  final m = masters[index];
                  final isSelected = _checked.contains(m.id);
                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _checked.remove(m.id);
                          } else {
                            _checked.add(m.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _checked.add(m.id);
                                  } else {
                                    _checked.remove(m.id);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                m.label,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checked.isEmpty
                  ? null
                  : () {
                      context.read<SettingsProvider>().setSelectedMasters(
                        _checked.toList(),
                      );
                    },
              child: Text(
                'Valider (${_checked.length} sélectionné${_checked.length > 1 ? 's' : ''})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
