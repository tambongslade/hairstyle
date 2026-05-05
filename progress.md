 URL: ws://your-server:3003/try-on

  How to connect (Flutter)

  First add the package to your pubspec.yaml:
  dependencies:
    socket_io_client: ^3.0.2

  Then in your try-on screen:

  import 'package:socket_io_client/socket_io_client.dart' as IO;

  class TryOnScreen extends StatefulWidget {
    @override
    _TryOnScreenState createState() => _TryOnScreenState();
  }

  class _TryOnScreenState extends State<TryOnScreen> {
    late IO.Socket socket;
    int progress = 0;
    String stepText = '';
    bool isGenerating = false;

    @override
    void initState() {
      super.initState();
      connectSocket();
    }

    void connectSocket() {
      socket = IO.io(
        'https://api.lisbeauty.com/try-on',  // your server URL + /try-on namespace
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'customerId': currentUser.customerId})
          .disableAutoConnect()
          .build(),
      );

      socket.onConnect((_) => print('Socket connected'));

      // Listen for progress updates
      socket.on('tryon:progress', (data) {
        setState(() {
          progress = data['progress'];       // 0–100
          stepText = data['step'];           // "Blending hair with your skin tone"
          // data['detail'] is optional extra info
        });
      });

      // Listen for final result
      socket.on('tryon:complete', (data) {
        setState(() {
          isGenerating = false;
          progress = 100;
        });
        // data['imageUrl']       → "/uploads/tryon/generated-xxx.jpg"
        // data['tryOnId']        → UUID
        // data['generatedImage'] → same as imageUrl
        // data['styleName']      → "Boho Braids Long"
        navigateToResult(data);
      });

      // Listen for errors
      socket.on('tryon:error', (data) {
        setState(() => isGenerating = false);
        showErrorDialog(data['error']);
      });

      socket.connect();
    }

    // Call this when user taps "Try On"
    Future<void> generateTryOn() async {
      setState(() {
        isGenerating = true;
        progress = 0;
        stepText = 'Starting...';
      });

      // Send the normal HTTP request — progress comes via socket
      final response = await api.post('/api/v1/try-on/generate', ...);
      // The HTTP response also returns the result,
      // but the socket gives you real-time progress while waiting
    }

    @override
    void dispose() {
      socket.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: isGenerating
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(value: progress / 100),
                SizedBox(height: 16),
                Text('${progress}%', style: TextStyle(fontSize: 24)),
                SizedBox(height: 8),
                Text(stepText, style: TextStyle(fontSize: 16)),
              ],
            )
          : YourNormalTryOnUI(),
      );
    }
  }

  Events summary

  ┌────────────────┬──────────────────────────────────────────┬────────────────────────────────┐
  │     Event      │                 Payload                  │          Description           │
  ├────────────────┼──────────────────────────────────────────┼────────────────────────────────┤
  │ tryon:progress │ {progress, step, detail?, timestamp}     │ Progress 0→100 with step label │
  ├────────────────┼──────────────────────────────────────────┼────────────────────────────────┤
  │ tryon:complete │ {tryOnId, imageUrl, generatedImage, ...} │ Final result                   │
  ├────────────────┼──────────────────────────────────────────┼────────────────────────────────┤
  │ tryon:error    │ {error, timestamp}                       │ Error message                  │
  └────────────────┴──────────────────────────────────────────┴────────────────────────────────┘

  Progress timeline

  ┌─────┬────────────────────────────────────────┐
  │  %  │            What's happening            │
  ├─────┼────────────────────────────────────────┤
  │ 5   │ Preparing your photo                   │
  ├─────┼────────────────────────────────────────┤
  │ 15  │ Photo ready                            │
  ├─────┼────────────────────────────────────────┤
  │ 20  │ Reference style loaded                 │
  ├─────┼────────────────────────────────────────┤
  │ 25  │ Generating hairstyle                   │
  ├─────┼────────────────────────────────────────┤
  │ 30  │ Analyzing your face and features       │
  ├─────┼────────────────────────────────────────┤
  │ 40  │ Matching hairstyle to your photo       │
  ├─────┼────────────────────────────────────────┤
  │ 50  │ Blending hair with your skin tone      │
  ├─────┼────────────────────────────────────────┤
  │ 60  │ Adjusting lighting and shadows         │
  ├─────┼────────────────────────────────────────┤
  │ 70  │ Refining hairline details              │
  ├─────┼────────────────────────────────────────┤
  │ 80  │ Almost there, adding finishing touches │
  ├─────┼────────────────────────────────────────┤
  │ 85  │ AI generation complete                 │
  ├─────┼────────────────────────────────────────┤
  │ 90  │ Saving your new look                   │
  ├─────┼────────────────────────────────────────┤
  │ 95  │ Finalizing                             │
  ├─────┼────────────────────────────────────────┤
  │ 100 │ Done!                                  │
  └─────┴────────────────────────────────────────┘

  The flow is: connect the socket first, then fire your normal HTTP POST to /api/v1/try-on/generate. While the HTTP request is pending, the socket pushes live progress updates. You get
   the result from both the socket (tryon:complete) and the HTTP response.
