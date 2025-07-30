# Väder Widget - Installationsguide

## Platsspårning
WeatherWidget stöder nu platsspårning för att visa väder baserat på din faktiska position.

### Aktivera platsspårning:
1. När du startar appen första gången kommer den begära tillåtelse för platsåtkomst
2. Klicka "Tillåt" för att aktivera platsbaserat väder
3. Om du nekar kommer widgeten visa demo-väder för Stockholm

### Demo-väder för Gotland/Ygne:
Om du befinner dig på Gotland (latitud 57-58°, longitud 18-19°) kommer widgeten visa:
- Temperatur: 18°
- Beskrivning: "Lätt bris"
- Plats: "Ygne, Gotland" (eller ortnamn baserat på din exakta position)

## OpenWeatherMap API Integration

För att få riktigt väder (inte demo-data):

### 1. Skaffa API-nyckel:
1. Gå till https://openweathermap.org/api
2. Registrera ett gratis konto
3. Kopiera din API-nyckel från dashboard

### 2. Lägg till API-nyckel i koden:
1. Öppna `Browser/WeatherWidget.swift`
2. Hitta rad 36: `private let apiKey = "YOUR_API_KEY_HERE"`
3. Ersätt `YOUR_API_KEY_HERE` med din riktiga API-nyckel
4. Bygg om projektet

### 3. API-begränsningar:
- Gratis plan: 60 anrop/minut, 1,000,000 anrop/månad
- Widgeten cachar väderdata för att minimera API-anrop
- Uppdaterar automatiskt när du byter plats

## Felsökning

### Om platsspårning inte fungerar:
1. Kontrollera Systeminställningar > Säkerhet & Integritet > Plats
2. Se till att Browser har tillåtelse att använda plats
3. Om du nekat tidigare, kan du återställa genom att ta bort appen från listan

### Om väder inte uppdateras:
1. Kontrollera att du har internetanslutning
2. Verifiera att API-nyckeln är korrekt
3. Kolla konsolloggen för eventuella felmeddelanden

## Säkerhet
- API-nyckeln lagras i koden (inte idealiskt för produktion)
- För produktion rekommenderas:
  - Lagra API-nyckel i Keychain
  - Använd en proxy-server för API-anrop
  - Implementera rate limiting