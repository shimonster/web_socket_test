import 'dart:io' show WebSocket, stdin;
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

void main(List<String> args) {
  print('client started');
  print(args);
  final address = 'ws://localhost:16969/${args[0]}';
  WebSocket.connect(address).then(
    (ws) {
      print('client connected to ws');
      print(ws.readyState);
      if (ws.readyState == WebSocket.open) {
        mainIsolate(ws).then((value) {
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

Future<void> inputIsolate(SendPort mainSendPort) async {
  while (true) {
    final input = stdin.readLineSync();
    mainSendPort.send(json.encode({'client message': input}));
  }
}

Future<void> mainIsolate(WebSocket ws) async {
  final mainRecievePort = ReceivePort();

  await Isolate.spawn(inputIsolate, mainRecievePort.sendPort);

  mainRecievePort.listen((message) {
    ws.add(message);
  });
}
