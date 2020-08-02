import 'dart:io' show WebSocket, WebSocketTransformer, HttpServer, stdin;
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

void main(List<String> args) {
  print('server started');
  HttpServer.bind('localhost', 16969).then(
    (server) {
      print('server set up as listening: ${server.port}');
      server.listen(
        (request) {
          WebSocketTransformer.upgrade(request).then(
            (ws) {
              if (ws.readyState == WebSocket.open) {
                mainIsolate(ws).then((value) {
                  ws.listen(
                    (event) {
                      print(
                          '${DateTime.now()}, ${Map<String, String>.from(json.decode(event))}');
                    },
                    onDone: () => print('done'),
                    onError: (error) =>
                        print('server error listening to web socket: $error'),
                    cancelOnError: true,
                  );
                });
              }
            },
            onError: (error) => print('server error upgrading request: $error'),
          );
        },
        onError: (error) => print('server error listening to server: $error'),
      );
    },
    onError: (error) => print('server error binding: $error'),
  );
}

Future<void> inputIsolate(SendPort mainSendPort) async {
  while (true) {
    final input = stdin.readLineSync();
    mainSendPort.send(json.encode({'server message': input}));
  }
}

Future<void> mainIsolate(WebSocket ws) async {
  final mainRecievePort = ReceivePort();

  await Isolate.spawn(inputIsolate, mainRecievePort.sendPort);

  mainRecievePort.listen((message) {
    ws.add(message);
  });
}
