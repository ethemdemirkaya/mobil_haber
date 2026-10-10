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

/// Haber sitelerine ve görsel CDN'lerine gönderilen tarayıcı kullanıcı
/// ajanı. Bazı CDN'ler (ör. content-media.investing.com) varsayılan
/// `Dart/x.y (dart:io)` ajanına 403 döndürüyor.
const String kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 13; mobil_haber) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// Ağdan görsel yüklerken (`CachedNetworkImage.httpHeaders`) kullanılır.
const Map<String, String> kImageRequestHeaders = {
  'User-Agent': kBrowserUserAgent,
};
