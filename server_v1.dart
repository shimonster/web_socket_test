import 'dart:io' show WebSocket, WebSocketTransformer, HttpServer, stdin;
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

void main(List<String> args) {
  final mainPort = ReceivePort();
  List<ClientIsolate> clientIsolates = [];
  Map<String, SendPort> clientPorts = {};
  Map<String, WebSocket> clientSockets = {};
  print('server started');
  HttpServer.bind('localhost', 16969).then(
    /// creates the server ^^^^^^^^^^^
    (server) async {
      /// when created the [server] <---------
      print('server set up as listening: ${server.port}');
      await Isolate.spawn(inputIsolate, {'allClients': clientIsolates});

      /// await isolates.spawnInputIsolate();
      server.listen(
        (request) {
          /// This trigers when a [request] is sent <---------

          print('server recieved request');
          print(request.uri);
          final uid = request.uri.pathSegments[0];

          mainPort.listen((clientPort) {
            clientPort.send(request);
          });

          clientIsolates.add(ClientIsolate(
            uid,
            mainPort,
          ));
        },
        onError: (error) => print('server error listening to server: $error'),
      );
    },
    onError: (error) => print('server error binding: $error'),
  );
}

void inputIsolate(Map<String, dynamic> message) {
  while (true) {
    final input = stdin.readLineSync();
    message['allClients'].forEach((value) {
      value.send(input);
    });
  }
}

clientIsolate(mainSendPort) async {
  print('isolate created');
  final thisRecievePort = ReceivePort();
  mainSendPort.send(thisRecievePort.sendPort);
  print('after isolate send to message port');
  final void Function(dynamic) addToWs = await thisRecievePort.first;
  print('isolate init finished');
  WebSocketTransformer.upgrade(request).then(
    /// upgreades the request to a web socket ^^^^^^^^^^^^^^
    (ws) async {
      /// when upgraded [ws] is the web socket <---------
      /// sends initial data to client web socket when created <--------
      final thisIsolate = ClientIsolate(uid, mainPort, ws);

      clientSockets.putIfAbsent(uid, () => ws);
      clientIsolates.add(thisIsolate);
      await thisIsolate.awaitInit(ws);
      clientPorts.putIfAbsent(uid, () => thisIsolate.isolateSendPort);
      thisIsolate.isolateSendPort.send(request);

      print('received client send port');
      clientPorts.putIfAbsent(
          uid,
          () => clientIsolates
              .lastWhere((element) => element.uid == uid)
              .isolateSendPort);
      if (ws.readyState == WebSocket.open) {
        /// if [ws] is open, do this stuff <---------
        ws.listen(
          (event) {
            /// listens to [event]s from the web socket <---------
            print(
                '${DateTime.now()}, ${Map<String, String>.from(json.decode(event))}');

            final wsMessage = Map<String, String>.from(json.decode(event))
                .values
                .toString()[0];

            clientIsolates.removeWhere((isl) => uid == isl.uid);
            clientIsolates.forEach((isl) {
              clientPorts[uid].send(wsMessage);
            });
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

  // thisWs.add(json.encode({DateTime.now().toString(): 'recieveMessage'}));
  thisRecievePort.listen((recieveMessage) {
    addToWs(json.encode({DateTime.now().toString(): recieveMessage}));
  });
}

class ClientIsolate {
  ClientIsolate(this.uid, this.mainPort, this.ws) {
    spawnClientIsolate();
  }

  final internalPort = ReceivePort();
  SendPort isolateSendPort;
  final String uid;
  final ReceivePort mainPort;
  final WebSocket ws;

  Future<void> awaitInit(WebSocket inputWs) async {
    print('await init future started');
    // var asyncMap = await mainPort.asyncMap((event) {
    //   isolateSendPort = event;
    // });
    isolateSendPort = await mainPort.first;
    print(isolateSendPort);
    print('await init after recieve isolate send port');
    // await mainPort.drain();
  }

  Future<void> spawnClientIsolate() async {
    print('brfore spawn');
    await Isolate.spawn(clientIsolate, mainPort.sendPort)
        .then((value) => print('after spawn'));
  }
}

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// class Isolates1 {
//   final mainPort = ReceivePort();
//   Map<String, SendPort> clientPorts = {};

//   static inputIsolate(Map<String, SendPort> message) {
//     while (true) {
//       final input = stdin.readLineSync();
//       message.forEach((key, value) {
//         value.send(input);
//       });
//     }
//   }

//   Future<void> spawnInputIsolate() async {
//     mainPort.listen((message) {
//       clientPorts.putIfAbsent(message['id'], () => message['port']);
//     });
//     await Isolate.spawn(inputIsolate, clientPorts);
//   }

//   static clientIsolate(message) async {
//     final thisRecievePort = ReceivePort();
//     final String thisId = message['clientId'];
//     final SendPort mainSendPort = message['mainPort'];
//     final Map<String, SendPort> allSendPorts = message['allSendPorts'];
//     mainSendPort.send({'port': thisRecievePort.sendPort, 'id': thisId});
//     final WebSocket thisWs = await thisRecievePort.first;

//     thisRecievePort.listen((recieveMessage) {
//       thisWs.add(json.encode({DateTime.now().toString(): recieveMessage}));
//     });

//     thisWs.listen((event) {
//       print('$thisId: $event');
//       final wsMessage =
//           Map<String, String>.from(json.decode(event)).values.toString()[0];
//       allSendPorts.removeWhere((key, value) => key == thisId);
//       allSendPorts.forEach((key, value) {
//         value.send(wsMessage);
//       });
//     });
//   }

//   Future<void> spawnClientIsolate(String clientId, WebSocket ws) async {
//     await Isolate.spawn(clientIsolate, {
//       'clientId': clientId,
//       'allSendPorts': clientPorts,
//       'mainPort': mainPort.sendPort
//     });
//     clientPorts[clientId].send(ws);
//   }
// }
