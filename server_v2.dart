import 'dart:io' show WebSocket, stdin, HttpServer, WebSocketTransformer;
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

void main() {
  print('server started');
  Map<String, WebSocket> clientSockets = {};

  HttpServer.bind('localhost', 42069).then((server) {
    spawnInputIsolate(clientSockets).then((value) {
      print('after threads');
      server.listen((request) {
        final uid = request.uri.pathSegments[0];
        WebSocketTransformer.upgrade(request).then(
          (ws) {
            print('a client connected to ws');
            clientSockets.putIfAbsent(uid, () => ws);
            if (ws.readyState == WebSocket.open) {
              ws.listen(
                (event) {
                  print('${event}');
                  final messageId = json.decode(event)['uid'];
                  clientSockets.forEach((key, value) {
                    if (key != messageId) {
                      value.add(event);
                    }
                  });
                },
                onDone: () {
                  print('listening to seb socket finished');
                  clientSockets.remove(uid);
                },
                onError: (error) {
                  print('client error listening to web socket: $error');
                  clientSockets.remove(uid);
                },
                cancelOnError: true,
              );
            }
          },
          onError: (error) =>
              print('client error contacing web socker: $error'),
        );
      });
    });
  });
}

Future<void> inputIsolate(SendPort mainSendPort) async {
  while (true) {
    final input = stdin.readLineSync();
    mainSendPort.send(json.encode({'client message': input}));
  }
}

Future<void> spawnInputIsolate(Map<String, WebSocket> clientSockets) async {
  final mainRecievePort = ReceivePort();

  await Isolate.spawn(inputIsolate, mainRecievePort.sendPort);

  mainRecievePort.listen((message) {
    clientSockets.forEach((uid, ws) {
      ws.add(json.encode({DateTime.now().toString(): message}));
    });
  });
}
