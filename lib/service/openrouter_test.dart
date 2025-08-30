import 'package:flutter/material.dart';
import 'gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test class to demonstrate OpenRouter fallback functionality
class OpenRouterTest {
  static final GeminiService _geminiService = GeminiService.instance;

  /// Test the OpenRouter fallback functionality
  static Future<void> testOpenRouterFallback(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing AI providers...'),
            ],
          ),
        ),
      );

      // Test both providers
      final providerStatus = await _geminiService.testProviders();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI Provider Status'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProviderStatus('Gemini', providerStatus['gemini']),
                const SizedBox(height: 16),
                _buildProviderStatus(
                    'OpenRouter', providerStatus['openRouter']),
                const SizedBox(height: 16),
                _buildCurrentStatus(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Test OpenRouter meal generation specifically
  static Future<void> testMealGeneration(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing OpenRouter meal generation...',
                  style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

      print('Before switch: ${_geminiService.currentProviderName}');
      _geminiService.switchToProvider(AIProvider.openrouter);
      print('After switch: ${_geminiService.currentProviderName}');

      // Get current provider status
      final currentProvider = _geminiService.currentProviderName;
      print('Current provider: $currentProvider');

      // Check if OpenRouter API key is available
      final openRouterApiKey = dotenv.env['OPENROUTER_API_KEY'];
      print(
          'OpenRouter API Key available: ${openRouterApiKey != null && openRouterApiKey.isNotEmpty}');

      // Generate a meal using the current provider
      final result = await _geminiService.generateMealPlan(
        'Generate 2 healthy breakfast meals with detailed recipes',
        'Quick and nutritious options with full ingredients and instructions',
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Print full result to console for debugging
      print('=== FULL MEAL GENERATION RESULT ===');
      print('Provider: $currentProvider');
      print('source: ${result['source']}');
      print('count: ${result['count']}');
      print('meals: ${result['meals']}');
      print('Result: ${result}');

      print('===================================');

      // Show results in dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('OpenRouter Meal Generation Test',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Provider: $currentProvider',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Source: ${result['source']}'),
                        const SizedBox(height: 8),
                        Text('Count: ${result['count']}'),
                        const SizedBox(height: 8),
                        Text(
                            'Total Meals Generated: ${(result['meals'] as List<dynamic>).length}'),
                        const SizedBox(height: 16),
                        const Text('Meal Titles:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...(result['meals'] as List<dynamic>).map(
                          (meal) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${meal['title']}'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Full Result (JSON):',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.toString(),
                            style: const TextStyle(
                                fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OpenRouter meal generation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // Also print error to console
      print('=== ERROR ===');
      print('Error: $e');
      print('=============');
    }
  }

  /// Configure OpenRouter settings
  static Future<void> configureOpenRouter(BuildContext context) async {
    final availableModels = _geminiService.getAvailableOpenRouterModels();
    final currentModel =
        _geminiService.getProviderStatus()['preferredOpenRouterModel'];

    String? selectedModel = currentModel;
    bool fallbackEnabled =
        _geminiService.getProviderStatus()['openRouterFallbackEnabled'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('OpenRouter Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fallback toggle
              SwitchListTile(
                title: const Text('Enable OpenRouter Fallback'),
                subtitle: const Text('Use OpenRouter when Gemini fails'),
                value: fallbackEnabled,
                onChanged: (value) {
                  setState(() {
                    fallbackEnabled = value;
                  });
                  _geminiService.setOpenRouterFallback(value);
                },
              ),

              const SizedBox(height: 16),

              // Model selection
              const Text('Preferred Model:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedModel,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Model',
                ),
                items: availableModels
                    .map(
                      (model) => DropdownMenuItem(
                        value: model,
                        child: Text(model),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedModel = value;
                  });
                  if (value != null) {
                    _geminiService.setPreferredOpenRouterModel(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('OpenRouter configuration updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build provider status widget
  static Widget _buildProviderStatus(String name, Map<String, dynamic> status) {
    final isAvailable = status['available'] as bool? ?? false;
    final statusCode = status['statusCode'];
    final error = status['error'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.error,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Status: ${isAvailable ? 'Available' : 'Unavailable'}'),
            if (statusCode != null) Text('Status Code: $statusCode'),
            if (error != null)
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  /// Build current status widget
  static Widget _buildCurrentStatus() {
    final status = _geminiService.getProviderStatus();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Current Provider: ${status['currentProviderName']}'),
            Text('Any Provider Healthy: ${status['anyProviderHealthy']}'),
            Text('Fallback Enabled: ${status['openRouterFallbackEnabled']}'),
            Text('Preferred Model: ${status['preferredOpenRouterModel']}'),
          ],
        ),
      ),
    );
  }
}
