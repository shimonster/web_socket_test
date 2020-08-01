import 'dart:io' show WebSocket, stdin;
import 'dart:convert';

void main(List<String> args) {
  const address = 'ws://localhost:6969';
  WebSocket.connect(address).then(
    (ws) {
      ws.listen(
        (event) {
          print(
              '${DateTime.now()}, $address, ${Map<String, String>.from(json.decode(event))}');
          final dataInput = stdin.readLineSync();
          ws.add(json.encode({'client typed': dataInput}));
        },
        onDone: () => print('listening to seb socket finished'),
        onError: (error) =>
            print('client error listening to web socket: $error'),
        cancelOnError: true,
      );
    },
    onError: (error) => print('client error contacing web socker: $error'),
  );
}
