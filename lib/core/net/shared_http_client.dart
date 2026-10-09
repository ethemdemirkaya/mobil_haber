import 'package:http/http.dart' as http;

/// Uygulama genelinde paylaşılan HTTP istemcisi.
///
/// Servisler eskiden her örnekte yeni bir `http.Client()` açıyor ve çoğu
/// hiç kapatılmıyordu (ör. her haber detayında sesli özet butonu iki
/// istemci açıyordu) — soketler birikiyor, bağlantılar yeniden
/// kullanılamıyordu. Tek istemci keep-alive bağlantılarını paylaşır.
///
/// Servisler bu istemciyi **kapatmamalı**; [closeIfOwned] yalnızca dışarıdan
/// verilmiş (ör. testteki MockClient) istemcileri kapatır.
final http.Client sharedHttpClient = http.Client();

/// [client] paylaşılan istemci değilse kapatır.
void closeIfOwned(http.Client client) {
  if (!identical(client, sharedHttpClient)) client.close();
}
