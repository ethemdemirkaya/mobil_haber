package com.ethemdemirkaya.pusula

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service, Flutter motorunu activity ile paylaşabilmek için
// AudioServiceActivity bekler. Düz FlutterActivity ile eklenti activity'ye
// bağlanırken önbellekte motor bulamayıp ikinci bir motor açıyor ve main()
// iki kez çalışıyordu: iki uygulama örneği aynı SQLite dosyalarını açıp
// birbirini kilitliyor (SQLITE_BUSY), görsel cache açılamıyor, kilit ekranı
// medya kontrolleri hiç çalışmıyordu.
class MainActivity : AudioServiceActivity()
