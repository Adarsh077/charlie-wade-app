import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfScreen extends StatefulWidget {
  PdfScreen(this.pdfUrl, {Key? key, this.initialPage = 1}) : super(key: key);

  final String pdfUrl;
  final int initialPage;

  @override
  _PdfScreenState createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  void _handleDoubleTap(Offset tapPosition, Size viewSize) {
    final rect = _pdfController.visibleRect;
    final pageIndex = (_pdfController.pageNumber ?? 1) - 1;
    final page = _pdfController.document.pages[pageIndex];
    final double pdfX =
        rect.left + (tapPosition.dx / viewSize.width) * rect.width;
    final double pdfY =
        rect.top + (tapPosition.dy / viewSize.height) * rect.height;
    final Offset tappedPdfPoint = Offset(pdfX, pdfY);

    final zoomedInLevel = _pdfController.getNextZoom();
    final currentVisibleWidth = _pdfController.visibleRect.width;

    final isAtFitWidth = currentVisibleWidth >= (page.width * 0.95);

    if (isAtFitWidth) {
      _pdfController.setZoom(tappedPdfPoint, zoomedInLevel);
    } else {
      _pdfController.setZoom(tappedPdfPoint, _pdfController.getPreviousZoom());
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  Future<void> onPageChange(int page) async {
    print('$page');
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('current-chapter-${widget.pdfUrl}', page);
  }

  @override
  void dispose() async {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top + 50;

    return Scaffold(
      body: PdfViewer.file(
        widget.pdfUrl,
        controller: _pdfController,
        params: PdfViewerParams(
          scrollByMouseWheel: 0.5,
          scrollPhysics: ClampingScrollPhysics(),
          backgroundColor: Colors.black,
          onViewerReady: (document, controller) {
            controller.goToPage(
              pageNumber: widget.initialPage,
              duration: Duration(milliseconds: 500),
            );
          },
          onPageChanged: (pageNumber) async {
            if (pageNumber == null) return;

            EasyDebounce.debounce(
              'page-changed',
              const Duration(milliseconds: 1000),
              () => onPageChange(pageNumber),
            );
          },
          viewerOverlayBuilder: (context, size, handleLinkTap) {
            return [
              GestureDetector(
                behavior: HitTestBehavior.translucent,

                onDoubleTapDown: (details) {
                  _handleDoubleTap(details.globalPosition, size);
                },

                child: IgnorePointer(
                  child: SizedBox(width: size.width, height: size.height),
                ),
              ),
            ];
          },

          boundaryMargin: EdgeInsets.only(top: statusBarHeight),
        ),
      ),
    );
  }
}
