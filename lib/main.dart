import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Game',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
      ),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _gameCodeController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  bool _isConnecting = false;

  void _joinGame() async {
    final gameCode = _gameCodeController.text.trim();
    final playerName = _playerNameController.text.trim();

    if (gameCode.length != 6 || !_isNumeric(gameCode)) {
      _showSnackBar('Game code must be exactly 6 digits');
      return;
    }

    if (playerName.isEmpty) {
      _showSnackBar('Please enter a player name');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GamePage(
            sessionId: gameCode,
            playerName: playerName,
          ),
        ),
      ).then((_) {
        setState(() {
          _isConnecting = false;
        });
      });
    } catch (e) {
      _showSnackBar('Failed to connect: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange,
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 30),

              // Title
              Text(
                'Trivia Game',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 50),

              // Game Code Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _gameCodeController,
                  decoration: InputDecoration(
                    labelText: 'Game Code (6 digits)',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.games, color: Colors.orange),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(20),
                    counterText: '',
                  ),
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ),
              SizedBox(height: 20),

              // Player Name Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TextField(
                  controller: _playerNameController,
                  decoration: InputDecoration(
                    labelText: 'Player Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.person, color: Colors.orange),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(20),
                  ),
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              SizedBox(height: 40),

              // Join Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _joinGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isConnecting
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Connecting...',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  )
                      : Text(
                    'Join Game',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final String sessionId;
  final String playerName;

  GamePage({required this.sessionId, required this.playerName});

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  WebSocketChannel? _channel;
  String _gameStatus = 'Connecting...';
  String _question = '';
  List<String> _answers = [];
  int _questionNumber = 0;
  int _timeLeft = 20;
  int? _selectedAnswer;
  bool _canAnswer = false;
  Timer? _timer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToGame();
  }

  void _connectToGame() async {
    try {
      final wsUrl = 'wss://quizzi-server.onrender.com/multiplayer/player/${widget.sessionId}';
      print('Connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Send player name
      _channel!.sink.add(json.encode({'player_name': widget.playerName}));

      // Listen to messages
      _channel!.stream.listen(
            (message) {
          print('Received: $message');
          try {
            final data = json.decode(message);
            _handleMessage(data);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _gameStatus = 'Connection error';
            _isConnected = false;
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            _gameStatus = 'Connection closed';
            _isConnected = false;
          });
        },
      );
    } catch (e) {
      print('Failed to connect: $e');
      setState(() {
        _gameStatus = 'Failed to connect: $e';
        _isConnected = false;
      });
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    print('Handling message: $data');

    switch (data['type']) {
      case 'joined':
        setState(() {
          _gameStatus = 'Joined successfully! Waiting for game to start...';
          _isConnected = true;
        });
        break;

      case 'game_started':
        setState(() {
          _gameStatus = 'Game started!';
        });
        break;

      case 'new_question':
        setState(() {
          _question = data['question']?.toString() ?? '';
          _answers = List<String>.from(data['answers'] ?? []);
          _questionNumber = (data['question_index'] ?? 0) + 1;
          _timeLeft = 20;
          _selectedAnswer = null;
          _canAnswer = true;
          _gameStatus = 'Question $_questionNumber';
        });
        _startTimer();
        break;

      case 'answer_received':
        print('Answer received by server');
        break;

      case 'question_ended':
        setState(() {
          _canAnswer = false;
          _gameStatus = 'Question ended';
        });
        _stopTimer();
        break;

      case 'game_ended':
        setState(() {
          _gameStatus = 'Game ended!';
          _canAnswer = false;
        });
        _stopTimer();

        // Show game results if available
        if (data['my_statistics'] != null) {
          _showGameResults(data['my_statistics']);
        }
        break;

      default:
        print('Unknown message type: ${data['type']}');
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && _canAnswer) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _submitAnswer(int answerIndex) {
    if (!_canAnswer || !_isConnected) return;

    setState(() {
      _selectedAnswer = answerIndex;
    });

    final message = json.encode({
      'action': 'submit_answer',
      'answer': answerIndex.toString(),
    });

    print('Sending answer: $message');
    _channel?.sink.add(message);
  }

  void _showGameResults(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: Text(
            'Game Results',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Questions: ${stats['total_questions'] ?? 0}',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(
                'Thank you for playing!',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Back to Main Menu',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getTimerColor() {
    if (_timeLeft > 15) return Colors.green;
    if (_timeLeft > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _stopTimer();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
              child: Center(
                child: Text(
                  widget.playerName[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Text(widget.playerName),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 15),
            child: Center(
              child: Text(
                'Pin: ${widget.sessionId}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Status and Timer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _gameStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_canAnswer && _timeLeft > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTimerColor(),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '00:${_timeLeft.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 30),

              // Question Content
              if (_question.isNotEmpty) ...[
                // Question Number
                Text(
                  'Question $_questionNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),

                // Question Text
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    _question,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 30),

                // Answer Buttons
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: List.generate(_answers.length, (index) {
                      final isSelected = _selectedAnswer == index;
                      return GestureDetector(
                        onTap: _canAnswer ? () => _submitAnswer(index) : null,
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : Colors.grey[700],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ] : null,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Answer ${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    _answers[index],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ] else ...[
                // Loading/Waiting State
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isConnected) ...[
                          Icon(
                            Icons.hourglass_empty,
                            size: 60,
                            color: Colors.orange,
                          ),
                          SizedBox(height: 20),
                          Text(
                            _gameStatus,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          CircularProgressIndicator(color: Colors.orange),
                          SizedBox(height: 20),
                          Text(
                            _gameStatus,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_gameStatus.contains('Failed') || _gameStatus.contains('error')) ...[
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: Text(
                                'Back to Main Menu',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}