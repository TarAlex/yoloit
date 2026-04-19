// On web (dart.library.html available): export GuestApp only — no native deps.
// On desktop (dart.library.io): export the full App.
export 'app.dart'       if (dart.library.html) 'app_guest.dart';
