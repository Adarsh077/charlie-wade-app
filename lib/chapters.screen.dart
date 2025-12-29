import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charlie_wade/pdf.screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChaptersScreen extends StatefulWidget {
  const ChaptersScreen({super.key});

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  List<String> chapters = [];
  bool isChaptersLoading = false;
  String? currentChapter;
  String? downloadingChapter;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, openCurrentChapter);
  }

  void openCurrentChapter() async {
    final prefs = await SharedPreferences.getInstance();
    final currentChapter = prefs.getString('current-chapter');
    if (currentChapter != null) {
      // ignore: use_build_context_synchronously
      final file = await createFileOfPdfUrl(currentChapter);
      int? initialPage = prefs.getInt('current-chapter-$currentChapter');
      if (initialPage == null) {
        initialPage = await getLastReadPage(currentChapter);
        prefs.setInt('current-chapter-$currentChapter', initialPage);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfScreen(
            file.path,
            initialPage: initialPage ?? 1,
            chapter: currentChapter,
          ),
        ),
      );

      // await OpenFilex.open(file.path);
    } else {
      fetchAllCapters();
    }
  }

  Future<File> createFileOfPdfUrl(String chapter) async {
    Completer<File> completer = Completer();
    try {
      final url =
          "https://charlie-wade-production-charliewadebucketbucket-hbcaevbr.s3.ap-south-1.amazonaws.com/$chapter";
      final filename = url.substring(url.lastIndexOf("/") + 1);

      var dir = await getApplicationDocumentsDirectory();
      File file = File("${dir.path}/$filename");

      if (await file.exists()) {
        return file;
      }

      var request = await HttpClient().getUrl(Uri.parse(url));
      var response = await request.close();
      var bytes = await consolidateHttpClientResponseBytes(response);

      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }

    return completer.future;
  }

  Future<int> getLastReadPage(String chapter) async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://yevklx5za1.execute-api.ap-south-1.amazonaws.com/chapters/$chapter/page",
        ),
      );

      String responseData = utf8.decode(response.bodyBytes);
      final data = json.decode(responseData);

      if (data['status'] == 'success') {
        return data['body']['page'] as int;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting last read page: $e');
      }
    }

    return 1; // Default page
  }

  void fetchAllCapters() async {
    setState(() {
      isChaptersLoading = true;
    });
    final response = await http.get(
      Uri.parse(
        "https://yevklx5za1.execute-api.ap-south-1.amazonaws.com/chapters",
      ),
    );

    String responseData = utf8.decode(response.bodyBytes);

    final data = json.decode(responseData);
    if (data['status'] == 'success') {
      final chaptersList = data['body']['chapters'] as List;
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString('current-chapter');

      setState(() {
        chapters = chaptersList.map((e) => e['name'] as String).toList();
        currentChapter = current;
        isChaptersLoading = false;
      });
    } else {
      // Handle error, maybe show a snackbar or something
      setState(() {
        isChaptersLoading = false;
      });
    }
  }

  void handleChapterClick(String chapter, BuildContext context) async {
    setState(() {
      downloadingChapter = chapter;
    });

    final file = await createFileOfPdfUrl(chapter);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('current-chapter', chapter);

    setState(() {
      currentChapter = chapter;
      downloadingChapter = null;
    });

    int? initialPage = prefs.getInt('current-chapter-$chapter');
    if (initialPage == null) {
      initialPage = await getLastReadPage(chapter);
      prefs.setInt('current-chapter-$chapter', initialPage);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfScreen(
          file.path,
          initialPage: initialPage ?? 1,
          chapter: chapter,
        ),
      ),
    );
    // await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charlie Wade')),
      body: Builder(
        builder: (context) {
          if (chapters.isEmpty && !isChaptersLoading) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  prefs.remove('current-chapter');

                  fetchAllCapters();
                },
                child: const Text('Reload'),
              ),
            );
          }

          if (isChaptersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            separatorBuilder: (context, index) => const Divider(height: 3),
            itemBuilder: (context, index) {
              final isCurrentChapter = chapters[index] == currentChapter;
              final isDownloading = chapters[index] == downloadingChapter;
              return ListTile(
                onTap: isDownloading
                    ? null
                    : () => handleChapterClick(chapters[index], context),
                dense: true,
                title: Text(chapters[index]),
                trailing: isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isCurrentChapter
                    ? const Icon(Icons.check_circle)
                    : null,
              );
            },
            itemCount: chapters.length,
          );
        },
      ),
    );
  }
}
