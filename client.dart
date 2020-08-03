import 'dart:io' show WebSocket, stdin;
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

void main(List<String> args) {
  print('client started');
  print(args);
  final address = 'ws://localhost:42069/${args[0]}';
  WebSocket.connect(address).then(
    (ws) {
      print('client connected to ws');
      print(ws.readyState);
      if (ws.readyState == WebSocket.open) {
        mainIsolate(ws, args[0]).then((value) {
          print('after threads');
          ws.listen(
            (event) {
              print(
                  '${DateTime.now()}, ${Map<String, String>.from(json.decode(event))}');
            },
            onDone: () => print('listening to seb socket finished'),
            onError: (error) =>
                print('client error listening to web socket: $error'),
            cancelOnError: true,
          );
        });
      }
    },
    onError: (error) => print('client error contacing web socker: $error'),
  );
}

Future<void> inputIsolate(Map<String, dynamic> message) async {
  while (true) {
    final input = stdin.readLineSync();
    message['sp'].send(
        json.encode({DateTime.now().toString(): input, 'uid': message['uid']}));
  }
}

Future<void> mainIsolate(WebSocket ws, String uid) async {
  final mainRecievePort = ReceivePort();

  await Isolate.spawn(
      inputIsolate, {'sp': mainRecievePort.sendPort, 'uid': uid});

  mainRecievePort.listen((message) {
    ws.add(message);
  });
}
