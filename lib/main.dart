import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/storage/photo_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();



  await Supabase.initialize(
    url: 'https://ltbqqpcyiwjwqhodwubl.supabase.co',
    publishableKey: 'sb_publishable_dGivkasS2lnLCUEU28Pi8Q_ODjO7pWP',
  );

  await Hive.initFlutter();

  await PhotoStorageService.init();

   runApp(
    const PhotoBoothApp(),
  );
}
