import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as viewer;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const LeafNote()); }
class LeafNote extends StatelessWidget {
  const LeafNote({super.key});
  @override Widget build(BuildContext context) => MaterialApp(title: 'LeafNote', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff387d68), useMaterial3: true), home: const Library());
}
class Library extends StatefulWidget { const Library({super.key}); @override State<Library> createState()=>_LibraryState(); }
class _LibraryState extends State<Library> {
  List<String> books = [];
  String query = '';
  bool importing = false;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => books = prefs.getStringList('books') ?? []);
  }

  Future<void> _add(String path) async {
    books.remove(path);
    books.insert(0, path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('books', books);
    if (mounted) setState(() {});
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _import() async {
    if (importing) return;
    setState(() => importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true,
      );
      if (result == null) return;
      final dir = await getApplicationDocumentsDirectory();
      var added = 0;
      for (final file in result.files) {
        if (file.path == null) continue;
        final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${added}_${file.name}';
        await File(file.path!).copy(target);
        await _add(target);
        added++;
      }
      if (added > 0) _message('$added개 PDF를 서재에 추가했어요');
    } catch (e) {
      _message('가져오기 실패: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> _create() async {
    final content = TextEditingController();
    final title = TextEditingController(text: '새 문서');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('텍스트로 PDF 만들기'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: '문서 제목')),
                TextField(controller: content, minLines: 5, maxLines: 12, decoration: const InputDecoration(labelText: '내용')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('PDF 생성')),
          ],
        ),
      );
      if (ok != true) return;
      if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
        _message('제목과 내용을 입력해 주세요');
        return;
      }
      final fontBytes = await DefaultAssetBundle.of(context).load('assets/fonts/NanumGothic.ttf');
      final koreanFont = pw.Font.ttf(fontBytes);
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: koreanFont, bold: koreanFont),
        build: (_) => [
          pw.Header(level: 0, child: pw.Text(title.text.trim())),
          pw.Text(content.text),
        ],
      ));
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.pdf';
      await File(path).writeAsBytes(await document.save());
      await _add(path);
      _message('PDF를 만들었어요');
    } catch (e) {
      _message('PDF 생성 실패: $e');
    } finally {
      content.dispose();
      title.dispose();
    }
  }

  Future<void> _remove(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('책을 삭제할까요?'),
        content: const Text('서재에서 제거하고 앱에 저장된 PDF 파일도 삭제합니다. 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      books.remove(path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('books', books);
      await prefs.remove('ink:$path');
      await prefs.remove('page:$path');
      await prefs.remove('bookmarks:$path');
      if (mounted) setState(() {});
      _message('삭제했어요');
    } catch (e) {
      _message('삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = books.where((path) =>
      path.split('/').last.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('LeafNote'), actions: [
        IconButton(
          tooltip: '앱 정보',
          onPressed: () => showAboutDialog(
            context: context, applicationName: 'LeafNote',
            applicationVersion: '0.2', children: [const Text('오프라인 PDF 서재 · 필기 · 북마크')],
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('내 서재', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${books.length}권의 문서', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '파일명으로 검색',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                isDense: true,
              ),
            ),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_stories_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(books.isEmpty ? '서재가 비어 있어요' : '검색 결과가 없어요',
                      style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(books.isEmpty ? 'PDF를 가져오거나 새 문서를 만들어 보세요' : '다른 파일명으로 검색해 보세요'),
                  ]),
                ))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final path = filtered[i];
                    final exists = File(path).existsSync();
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
                      title: Text(path.split('/').last, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(exists ? '이어서 읽기' : '파일을 찾을 수 없음'),
                      onTap: exists ? () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => Reader(path: path)));
                        if (mounted) setState(() {});
                      } : null,
                      trailing: IconButton(
                        tooltip: '문서 삭제', icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(path),
                      ),
                    );
                  },
                ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: importing ? null : _import,
              icon: const Icon(Icons.file_open),
              label: Text(importing ? '가져오는 중' : 'PDF 가져오기'),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              onPressed: _create, icon: const Icon(Icons.add),
              label: const Text('PDF 만들기'),
            )),
          ]),
        ),
      ),
    );
  }
}
class InkStroke { InkStroke(this.points,this.color,this.width); final List<Offset> points; final int color; final double width;
 Map<String,dynamic> toJson()=>{'points':points.map((p)=>[p.dx,p.dy]).toList(),'color':color,'width':width};
 factory InkStroke.fromJson(Map<String,dynamic> j)=>InkStroke((j['points'] as List).map((p)=>Offset((p[0] as num).toDouble(),(p[1] as num).toDouble())).toList(),j['color'] as int,(j['width'] as num).toDouble()); }
class Reader extends StatefulWidget {const Reader({super.key,required this.path});final String path;@override State<Reader> createState()=>_ReaderState();}
class _ReaderState extends State<Reader>{
 viewer.PdfDocument? doc; Uint8List? pageImage; int page=1,total=0; double pageRatio=0.707; bool draw=false,busy=false; Color ink=Colors.red; double width=0.004;
 Map<int,List<InkStroke>> strokes={}; List<Offset> current=[]; Set<int> bookmarks={}; String? loadError; bool exporting=false;
 String get key=>'ink:${widget.path}';
 @override void initState(){super.initState();_open();}
 Future<void> _open() async {try{final d=await viewer.PdfDocument.openFile(widget.path);final p=await SharedPreferences.getInstance(); final raw=p.getString(key); if(raw!=null){final decoded=jsonDecode(raw) as Map<String,dynamic>;strokes=decoded.map((k,v)=>MapEntry(int.parse(k),(v as List).map((s)=>InkStroke.fromJson(Map<String,dynamic>.from(s))).toList()));}doc=d;total=d.pagesCount;bookmarks=(p.getStringList('bookmarks:${widget.path}')??[]).map(int.tryParse).whereType<int>().toSet();page=(p.getInt('page:${widget.path}')??1).clamp(1,total);await _render();}catch(e){if(mounted)setState(()=>loadError='PDF를 열 수 없습니다: $e');}}
 Future<void> _render() async {if(doc==null||busy)return;setState(()=>busy=true);try{final p=await doc!.getPage(page);final ratio=p.width/p.height; final image=await p.render(width:p.width*2,height:p.height*2,format:viewer.PdfPageImageFormat.png);await p.close();if(mounted)setState((){pageRatio=ratio;pageImage=image?.bytes;});}catch(e){if(mounted)setState(()=>loadError='페이지 표시 실패: $e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setString(key,jsonEncode(strokes.map((k,v)=>MapEntry('$k',v.map((s)=>s.toJson()).toList()))));await p.setInt('page:${widget.path}',page);}
 Future<void> _turn(int delta) async => _goTo(page + delta);
 Future<void> _goTo(int target) async {
   if (busy || total == 0 || target < 1 || target > total || target == page) return;
   await _save();
   if (!mounted) return;
   setState(() { page = target; pageImage = null; current = []; });
   await _render();
 }
 Future<void> _toggleBookmark() async {
   setState(() {
     if (!bookmarks.add(page)) bookmarks.remove(page);
   });
   final prefs = await SharedPreferences.getInstance();
   await prefs.setStringList('bookmarks:${widget.path}', bookmarks.map((e) => '$e').toList());
 }
 Future<void> _showBookmarks() async {
   final selected = await showModalBottomSheet<int>(
     context: context,
     showDragHandle: true,
     builder: (ctx) => SafeArea(
       child: ListView(
         shrinkWrap: true,
         children: [
           const ListTile(title: Text('북마크'), subtitle: Text('저장한 페이지로 이동')),
           if (bookmarks.isEmpty) const ListTile(title: Text('아직 저장된 북마크가 없어요')),
           for (final number in bookmarks.toList()..sort())
             ListTile(
               leading: const Icon(Icons.bookmark),
               title: Text('$number 페이지'),
               onTap: () => Navigator.pop(ctx, number),
             ),
         ],
       ),
     ),
   );
   if (selected != null) await _goTo(selected);
 }
 Future<void> _jumpToPage() async {
   final controller = TextEditingController(text: '$page');
   final selected = await showDialog<int>(
     context: context,
     builder: (ctx) => AlertDialog(
       title: const Text('페이지 이동'),
       content: TextField(
         controller: controller,
         keyboardType: TextInputType.number,
         autofocus: true,
         decoration: InputDecoration(labelText: '1 ~ $total 페이지'),
       ),
       actions: [
         TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
         FilledButton(
           onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
           child: const Text('이동'),
         ),
       ],
     ),
   );
   controller.dispose();
   if (selected != null) await _goTo(selected);
 }
 Future<void> _export() async {
   if (doc == null || exporting) return;
   setState(() => exporting = true);
   final output = pw.Document();
   try {
     for (int i = 1; i <= total; i++) {
       final sourcePage = await doc!.getPage(i);
       final w = sourcePage.width;
       final h = sourcePage.height;
       final image = await sourcePage.render(
         width: w * 2,
         height: h * 2,
         format: viewer.PdfPageImageFormat.png,
       );
       await sourcePage.close();
       if (image == null) continue;
       final pageStrokes = strokes[i] ?? <InkStroke>[];
       output.addPage(
         pw.Page(
           pageFormat: pdf.PdfPageFormat(w, h),
           margin: pw.EdgeInsets.zero,
           build: (context) => pw.Stack(
             children: [
               pw.Positioned.fill(
                 child: pw.Image(
                   pw.MemoryImage(image.bytes),
                   fit: pw.BoxFit.fill,
                 ),
               ),
               for (final stroke in pageStrokes)
                 if (stroke.points.length > 1)
                   pw.CustomPaint(
                     size: pdf.PdfPoint(w, h),
                     painter: (canvas, size) {
                       canvas.setStrokeColor(PdfColorCompat(stroke.color).toPdf());
                       canvas.setLineWidth(stroke.width * w);
                       for (var n = 1; n < stroke.points.length; n++) {
                         final a = stroke.points[n - 1];
                         final b = stroke.points[n];
                         canvas.drawLine(
                           a.dx * w, h - a.dy * h,
                           b.dx * w, h - b.dy * h,
                         );
                         canvas.strokePath();
                       }
                     },
                   ),
             ],
           ),
         ),
       );
     }
     final dir = await getTemporaryDirectory();
     final path = '${dir.path}/LeafNote_${DateTime.now().millisecondsSinceEpoch}.pdf';
     await File(path).writeAsBytes(await output.save());
     await Share.shareXFiles([XFile(path)], text: '필기 포함 PDF');
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('내보내기 실패: $e')),
       );
     }
   } finally {
     if (mounted) setState(() => exporting = false);
   }
 }
 @override void dispose(){_save();doc?.close();super.dispose();}
 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text(widget.path.split('/').last, overflow: TextOverflow.ellipsis),
       actions: [
         IconButton(tooltip: '북마크 목록', onPressed: _showBookmarks, icon: const Icon(Icons.bookmarks_outlined)),
         IconButton(tooltip: bookmarks.contains(page) ? '북마크 해제' : '북마크 추가', onPressed: total == 0 ? null : _toggleBookmark, icon: Icon(bookmarks.contains(page) ? Icons.bookmark : Icons.bookmark_border)),
         IconButton(
           tooltip: '공유',
           onPressed: exporting ? null : _export,
           icon: exporting ? const Icon(Icons.hourglass_top) : const Icon(Icons.ios_share),
         ),
         IconButton(
           tooltip: '필기 모드',
           onPressed: () => setState(() => draw = !draw),
           icon: Icon(draw ? Icons.edit : Icons.pan_tool_outlined),
         ),
       ],
     ),
     body: Column(
       children: [
         if (draw)
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               for (final c in [Colors.red, Colors.blue, Colors.black])
                 IconButton(
                   onPressed: () => setState(() => ink = c),
                   icon: Icon(Icons.circle, color: c),
                 ),
               TextButton(
                 onPressed: () {
                   final list = strokes[page];
                   if (list != null && list.isNotEmpty) {
                     setState(() => list.removeLast());
                     _save();
                   }
                 },
                 child: const Text('되돌리기'),
               ),
             ],
           ),
         Expanded(
           child: LayoutBuilder(
             builder: (context, constraints) {
               if (loadError != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(loadError!, textAlign: TextAlign.center)));
               if (pageImage == null) {
                 return const Center(child: CircularProgressIndicator());
               }
               return InteractiveViewer(
                 panEnabled: !draw,
                 scaleEnabled: !draw,
                 minScale: 1,
                 maxScale: 4,
                 child: Center(
                 child: AspectRatio(
                   aspectRatio: _ratio(),
                   child: LayoutBuilder(
                     builder: (context, inner) {
                       return Stack(
                         fit: StackFit.expand,
                         children: [
                           Image.memory(pageImage!, fit: BoxFit.fill),
                           GestureDetector(
                             behavior: draw ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
                             onPanStart: draw
                                 ? (details) => setState(() {
                                       current = [_normalize(details.localPosition, inner.biggest)];
                                     })
                                 : null,
                             onPanUpdate: draw
                                 ? (details) => setState(() {
                                       current.add(_normalize(details.localPosition, inner.biggest));
                                     })
                                 : null,
                             onPanEnd: draw
                                 ? (details) {
                                     if (current.isNotEmpty) {
                                       setState(() {
                                         strokes.putIfAbsent(page, () => []).add(
                                           InkStroke(List.of(current), ink.toARGB32(), width),
                                         );
                                         current = [];
                                       });
                                       _save();
                                     }
                                   }
                                 : null,
                             child: CustomPaint(
                               painter: InkPainter([
                                 ...?strokes[page],
                                 if (current.isNotEmpty)
                                   InkStroke(current, ink.toARGB32(), width),
                               ]),
                             ),
                           ),
                         ],
                       );
                     },
                   ),
                 ),
                 ),
               );
             },
           ),
         ),
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
           children: [
             IconButton(tooltip: '이전 페이지', onPressed: page <= 1 ? null : () => _turn(-1), icon: const Icon(Icons.chevron_left)),
             TextButton(onPressed: total > 0 ? _jumpToPage : null, child: Text('$page / $total')),
             IconButton(tooltip: '다음 페이지', onPressed: page >= total ? null : () => _turn(1), icon: const Icon(Icons.chevron_right)),
           ],
         ),
       ],
     ),
   );
 }
 double _ratio(){return pageRatio;}
 Offset _normalize(Offset p,Size s){return Offset((p.dx/s.width).clamp(0.0,1.0),(p.dy/s.height).clamp(0.0,1.0));}
}
class InkPainter extends CustomPainter {InkPainter(this.strokes);final List<InkStroke> strokes;@override void paint(Canvas canvas,Size size){for(final s in strokes){if(s.points.isEmpty)continue;final paint=Paint()..color=Color(s.color)..strokeWidth=s.width*size.width..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;final path=Path()..moveTo(s.points.first.dx*size.width,s.points.first.dy*size.height);for(final p in s.points.skip(1)){path.lineTo(p.dx*size.width,p.dy*size.height);}canvas.drawPath(path,paint);}}@override bool shouldRepaint(covariant InkPainter old)=>true;}
class PdfColorCompat {PdfColorCompat(this.argb);final int argb;pdf.PdfColor toPdf()=>pdf.PdfColor(((argb>>16)&255)/255,((argb>>8)&255)/255,(argb&255)/255);}
