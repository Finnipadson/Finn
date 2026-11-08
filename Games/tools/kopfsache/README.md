# Kopfsache – Schachrätsel-Werkzeuge

`logic.js` ist eine Kopie des LOGIC-Blocks aus `kopfsache.html` (Generatoren + Schach-Engine).

```bash
node genbank.js mate1 60 1000              # Matt in 1   -> bank_mate1.json
node genbank.js mate2 90 2000              # Matt in 2   -> bank_mate2.json
node genbank.js mate3 60 5000              # Matt in 3   -> bank_mate3.json
node genbank.js tactic 9 10000 tac/t1.json # Taktiken (langsam, ~40 s pro Stück; mehrere Prozesse parallel starten)
node verify.js                             # prüft alles per Engine, schreibt bank.js
node polish.js                             # bevorzugt bei gleichwertigen Folgezügen das Schlagen
```

Danach den Inhalt von `bank.js` (`const CHESS_BANK = [...]`) in `kopfsache.html` ersetzen.
