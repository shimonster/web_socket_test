import 'dart:io'; // show WebSocket, WebSocketTransformer, HttpServer, stdin;
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

void main(List<String> args) {
  final isolates = Isolates();
  print('server started');
  HttpServer.bind('localhost', 16969).then(
    (server) async {
      print('server set up as listening: ${server.port}');
      await isolates.spawnInputIsolate();
      server.listen(
        (request) {
          WebSocketTransformer.upgrade(request).then(
            (ws) async {
              print('server recieved request');
              print(request.uri);
              await isolates.spawnClientIsolate(
                  request.uri.pathSegments[0], ws);
              if (ws.readyState == WebSocket.open) {
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

class Isolates {
  final mainPort = ReceivePort();
  Map<String, SendPort> clientPorts = {};

  static inputIsolate(Map<String, SendPort> message) {
    while (true) {
      final input = stdin.readLineSync();
      message.forEach((key, value) {
        value.send(input);
      });
    }
  }

  Future<void> spawnInputIsolate() async {
    mainPort.listen((message) {
      clientPorts.putIfAbsent(message['id'], () => message['port']);
    });
    await Isolate.spawn(inputIsolate, clientPorts);
  }

  static clientIsolate(message) {
    final WebSocket thisWs = message['ws'];
    final String thisId = message['clientId'];
    final SendPort mainSendPort = message['mainPort'];
    final Map<String, SendPort> allSendPorts = message['allSendPorts'];
    final thisRecievePort = ReceivePort();

    mainSendPort.send({'port': thisRecievePort.sendPort, 'id': thisId});

    thisRecievePort.listen((recieveMessage) {
      thisWs.add(json.encode({DateTime.now().toString(): recieveMessage}));
    });

    thisWs.listen((event) {
      print('$thisId: $event');
      final wsMessage =
          Map<String, String>.from(json.decode(event)).values.toString()[0];
      allSendPorts.removeWhere((key, value) => key == thisId);
      allSendPorts.forEach((key, value) {
        value.send(wsMessage);
      });
    });
  }

  Future<void> spawnClientIsolate(String clientId, WebSocket ws) async {
    await Isolate.spawn(clientIsolate, {
      'ws': ws,
      'clientId': clientId,
      'allSendPorts': clientPorts,
      'mainPort': mainPort.sendPort
    });
  }
}
