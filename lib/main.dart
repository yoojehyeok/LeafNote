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
  List<String> books=[];
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async { final p=await SharedPreferences.getInstance(); setState(()=>books=p.getStringList('books')??[]); }
  Future<void> _add(String path) async { if(!books.contains(path)) books.insert(0,path); final p=await SharedPreferences.getInstance(); await p.setStringList('books',books); setState((){}); }
  Future<void> _import() async { final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['pdf']); if(r==null||r.files.single.path==null)return;
    final source=File(r.files.single.path!); final dir=await getApplicationDocumentsDirectory(); final target='${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${r.files.single.name}'; await source.copy(target); await _add(target); }
  Future<void> _create() async { final c=TextEditingController(); final title=TextEditingController(text:'새 문서');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('텍스트로 PDF 만들기'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'제목')),TextField(controller:c,maxLines:8,decoration:const InputDecoration(labelText:'내용'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('생성'))]));
    if(ok!=true)return; final fontBytes=await DefaultAssetBundle.of(context).load('assets/fonts/NanumGothic.ttf'); final koreanFont=pw.Font.ttf(fontBytes); final doc=pw.Document(); doc.addPage(pw.MultiPage(theme:pw.ThemeData.withFont(base:koreanFont,bold:koreanFont),build:(_)=>[pw.Header(level:0,child:pw.Text(title.text)),pw.Text(c.text)]));
    try {final dir=await getApplicationDocumentsDirectory(); final path='${dir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf'; await File(path).writeAsBytes(await doc.save()); await _add(path);} catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF 생성 실패: $e')));} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('LeafNote · 내 서재')),body:books.isEmpty?const Center(child:Text('PDF를 가져오거나 새 문서를 만들어 보세요')):ListView.builder(itemCount:books.length,itemBuilder:(ctx,i){final path=books[i];return ListTile(leading:const Icon(Icons.menu_book_outlined),title:Text(path.split('/').last, maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(File(path).existsSync()?'탭하여 읽기':'파일을 찾을 수 없음'),onTap:File(path).existsSync()?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Reader(path:path))):null,trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{books.removeAt(i);final p=await SharedPreferences.getInstance();await p.setStringList('books',books);setState((){});}));}),bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:FilledButton.icon(onPressed:_import,icon:const Icon(Icons.file_open),label:const Text('PDF 가져오기'))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:_create,icon:const Icon(Icons.add),label:const Text('PDF 만들기')))]))));
}
class InkStroke { InkStroke(this.points,this.color,this.width); final List<Offset> points; final int color; final double width;
 Map<String,dynamic> toJson()=>{'points':points.map((p)=>[p.dx,p.dy]).toList(),'color':color,'width':width};
 factory InkStroke.fromJson(Map<String,dynamic> j)=>InkStroke((j['points'] as List).map((p)=>Offset((p[0] as num).toDouble(),(p[1] as num).toDouble())).toList(),j['color'] as int,(j['width'] as num).toDouble()); }
class Reader extends StatefulWidget {const Reader({super.key,required this.path});final String path;@override State<Reader> createState()=>_ReaderState();}
class _ReaderState extends State<Reader>{
 viewer.PdfDocument? doc; Uint8List? pageImage; int page=1,total=0; double pageRatio=0.707; bool draw=false,busy=false; Color ink=Colors.red; double width=0.004;
 Map<int,List<InkStroke>> strokes={}; List<Offset> current=[];
 String get key=>'ink:${widget.path}';
 @override void initState(){super.initState();_open();}
 Future<void> _open() async {try{final d=await viewer.PdfDocument.openFile(widget.path);final p=await SharedPreferences.getInstance(); final raw=p.getString(key); if(raw!=null){final decoded=jsonDecode(raw) as Map<String,dynamic>;strokes=decoded.map((k,v)=>MapEntry(int.parse(k),(v as List).map((s)=>InkStroke.fromJson(Map<String,dynamic>.from(s))).toList()));}doc=d;total=d.pagesCount;page=(p.getInt('page:${widget.path}')??1).clamp(1,total);await _render();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('열기 실패: $e')));}}
 Future<void> _render() async {if(doc==null||busy)return;setState(()=>busy=true);try{final p=await doc!.getPage(page);final ratio=p.width/p.height; final image=await p.render(width:p.width*2,height:p.height*2,format:viewer.PdfPageImageFormat.png);await p.close();if(mounted)setState((){pageRatio=ratio;pageImage=image?.bytes;});}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setString(key,jsonEncode(strokes.map((k,v)=>MapEntry('$k',v.map((s)=>s.toJson()).toList()))));await p.setInt('page:${widget.path}',page);}
 Future<void> _turn(int delta)async{if(busy||page+delta<1||page+delta>total)return;await _save();setState((){page+=delta;pageImage=null;});await _render();}
 Future<void> _export() async {
   if (doc == null) return;
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
   }
 }
 @override void dispose(){_save();doc?.close();super.dispose();}
 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text(widget.path.split('/').last, overflow: TextOverflow.ellipsis),
       actions: [
         IconButton(
           tooltip: '공유',
           onPressed: _export,
           icon: const Icon(Icons.ios_share),
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
               if (pageImage == null) {
                 return const Center(child: CircularProgressIndicator());
               }
               return Center(
                 child: AspectRatio(
                   aspectRatio: _ratio(),
                   child: LayoutBuilder(
                     builder: (context, inner) {
                       return Stack(
                         fit: StackFit.expand,
                         children: [
                           Image.memory(pageImage!, fit: BoxFit.fill),
                           GestureDetector(
                             behavior: HitTestBehavior.opaque,
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
               );
             },
           ),
         ),
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
           children: [
             IconButton(onPressed: () => _turn(-1), icon: const Icon(Icons.chevron_left)),
             Text('$page / $total'),
             IconButton(onPressed: () => _turn(1), icon: const Icon(Icons.chevron_right)),
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
