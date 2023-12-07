import 'dart:io';
import 'session.dart';
import 'dart:async';
import "dart:math";

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:bubble/bubble.dart';

void main() {
  initializeDateFormatting().then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: ChatPage(),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<types.Message> _messages = [];
  final _user = const types.User(
    id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
  );

  final _agent = const types.User(id: '1234');

  int _seconds = 0;
  bool _isRunning = false;
  late Timer _timer;

  void _startTimer() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _stopTimer() {
    _isRunning = false;
    _timer.cancel();
  }

  void _resetTimer() {
    setState(() {
      _seconds = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () => _initMessages(),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Clear Chat'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData.copyWith(title: ""),
    );
    if (previewData.title == "404 Not Found") {
      setState(() {
        _messages[index] = updatedMessage;
      });
    }
  }

  types.TextMessage _buildUserMessage(String text) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: text,
    );
    return textMessage;
  }

  types.TextMessage _buildAgentMessage(String text) {
    final textMessage = types.TextMessage(
      author: _agent,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: text,
    );
    return textMessage;
  }

  String _transformReponseText(String text) {
    text = text.replaceAll(")", " )");
    text = text.replaceAll("(", "( ");
    return text;
  }

  void _handleSendPressed(types.PartialText message) async {
    Map<String, String> requestData = {'query': message.text};
    _addMessage(_buildUserMessage(message.text));
    _addMessage(_buildAgentMessage("✅ 답변 생성 중... 잠시만 기다려 주세요 ☺️"));

    _startTimer();
    final dynamic response = await Session().post(
        'http://facerain-dev.iptime.org:1009/api/v1/chat/completion',
        requestData);

    _stopTimer();

    if (_seconds < 5) {
      await Future.delayed(const Duration(seconds: 2));
    }

    String agentMessageText = _transformReponseText(response['answer']);

    if (_seconds > 5) {
      _addMessage(_buildAgentMessage("✅ 답변 생성 완료"));
    }

    _addMessage(_buildAgentMessage(agentMessageText));

    _resetTimer();
  }

  void _initMessages() async {
    setState(() {
      _messages = [];
    });
  }

  void _loadMessages() async {
    List<String> exampleQueryList = [
      "컴퓨터공학과 졸업 요건에 대해 알려줘",
      "올해 SW 페스티벌 언제 열렸어?",
      "개발 관련된 취업이나 인턴 정보가 있을까?",
      "인공지능학과 전공 필수 과목 뭐 있어?",
      "SW 관련 대회 3개 추천해줘",
      "SW 관련된 봉사 활동 없을까",
      "올해 가을프로그래밍 경시대회 신청 링크 알려줘",
      "내년 대학원 모집 언제부터야?"
    ];

    final random = Random();
    String exampleQuery1 =
        exampleQueryList[random.nextInt(exampleQueryList.length)];

    _addMessage(_buildAgentMessage("안녕하세요, KHUGPT입니다! 무엇이 궁금한가요?"));
    _addMessage(_buildAgentMessage("이런 질문을 해볼 수 있어요 ✅"));
    _addMessage(_buildAgentMessage("Q. $exampleQuery1"));
  }

//give me some link about programming contest
  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) =>
      Bubble(
        color: _user.id != message.author.id ||
                message.type == types.MessageType.image
            ? const Color.fromRGBO(199, 160, 99, 1)
            : const Color.fromRGBO(160, 16, 26, 1),
        radius: const Radius.circular(20.0),
        nip: _user.id != message.author.id
            ? BubbleNip.leftTop
            : BubbleNip.rightTop,
        nipWidth: 6,
        nipHeight: 15,
        child: child,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: const Color.fromRGBO(160, 16, 26, 1),
          title: const Text(
            'KHUGPT',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Chat(
          theme: const DefaultChatTheme(
              receivedMessageBodyTextStyle: TextStyle(color: Colors.white),
              primaryColor: Colors.white,
              secondaryColor: Colors.white,
              receivedMessageBodyLinkTextStyle: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
              attachmentButtonIcon: Icon(
                Icons.add,
                color: Colors.white,
              )),
          messages: _messages,
          onAttachmentPressed: _handleAttachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          user: _user,
          bubbleBuilder: _bubbleBuilder,
        ),
      );
}
