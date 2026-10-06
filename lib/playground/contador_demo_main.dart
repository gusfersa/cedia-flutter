import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'contador_demo.dart';

void main() => runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale('es'),
        supportedLocales: [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ContadorDemo(),
      ),
    );
