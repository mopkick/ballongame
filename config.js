// Ballonalarm – Einstellungen
//
// Leer lassen = Einzelspieler: Das Spiel läuft komplett offline, die Bestenliste
// zeigt die besten Runden auf dem jeweiligen Gerät.
//
// Ausfüllen = Online-Modus: gemeinsame Bestenliste und Live-Lobby über Supabase.
// Beide Werte stehen in Supabase unter Project Settings → API Keys / Data API.
// Der "publishable" bzw. "anon" Key ist öffentlich gedacht und darf hier stehen.
// Niemals den "secret" oder "service_role" Key eintragen!
window.BALLONALARM_CONFIG = {
  supabaseUrl: '',   // z. B. 'https://abcdefghijkl.supabase.co'
  supabaseKey: ''    // z. B. 'sb_publishable_…' oder der anon-Key 'eyJ…'
};
