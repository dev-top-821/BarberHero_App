import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders a legal document (Terms & Conditions or Privacy Policy).
/// Loads the Markdown source from the bundled asset at [assetPath] —
/// canonical text lives in `Docs/terms/*.md` and is copied into
/// `assets/legal/` at build time. See `shared_models/src/legal.dart` for
/// the asset-path constants and update procedure.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load $title. Please try again later.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Markdown(
              data: snapshot.data!,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              selectable: true,
            );
          },
        ),
      ),
    );
  }
}
