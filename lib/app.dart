import 'package:flutter/material.dart';

import 'features/photobooth/photobooth_page.dart';

class PhotoBoothApp extends StatelessWidget {
  const PhotoBoothApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoBooth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PhotoBoothPage(),
    );
  }
}
