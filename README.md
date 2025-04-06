# Documentation de l’application serveur

## Réalisé par : Pierre-Sacha Baglione

## Architecture Monolithique

J’ai utilisé une architecture monolithique pour le serveur sans le partager en un serveur middleware, un serveur de traitement pour la base de données et un serveur de communication directe avec les clients.

```dart
await GlobalManager.instance.initialize();

final webSocketServer = WebSocketServer();
await webSocketServer.start();

runApp(const MainAppUi());
```

## Workflow de développement (GitHub)

De prime abord il faut préciser que la mécanique utilisée fut de fonctionner en workflow GitHub :

- Création d’une issue GitHub
- Branche associée (`devbranch`)
- Pull Request merge vers la branche `main`

## Mise en place de la base de données

De prime abord j’ai souhaité implémenter la base de données en utilisant **SQFlite**. J’ai créé des handlers pour éviter la manipulation directe de la base depuis les fonctions WebSocket.

> **Exemple : Initialisation et création des tables (fichier `database_functions.dart`)**
>
> ```dart
> Future<Database> _initDatabase() async {
>   final path = join(await getDatabasesPath(), 'app_database.db');
>   await deleteDatabase(path); 
>  pour les tests
>   return openDatabase(path, version: 1, onCreate: _onCreate);
> }
>
> Future<void> _onCreate(Database db, int version) async {
>   await db.execute('''
>     CREATE TABLE devices (
>       uniqueId TEXT PRIMARY KEY,
>       type TEXT NOT NULL,
>       apiKey TEXT NOT NULL,
>       timestamp TEXT NOT NULL
>     );
>   ''');
> }
> ```

## Serveur WebSocket et gestion des requêtes

La seconde étape fut de créer le serveur WebSocket pour traiter les requêtes JSON, convertir une action en chaîne de caractères, puis utiliser un `switch-case`.

> **Exemple : Traitement des requêtes (fichier `websocket_server.dart`)**
>
> ```dart
> switch (action) {
>   case 'register':
>     await _handleRegister(channel, data);
>     break;
>   case 'sendData':
>     await _handleData(channel, data);
>     break;
>   default:
>     channel.sink.add(jsonEncode({'status': 'error', 'message': 'Unknown action'}));
> }
> ```

## Tests unitaires

À chaque étape, des fonctions de tests unitaires ont été créées.

> **Exemple : Test unitaire d'insertion de données (fichier `database_functions_test.dart`)**
>
> ```dart
> test('insertStoredData and getStoredData', () async {
>   await dbFunctions.insertStoredData('CC-TS-TEST', 'testKey', 'testValue');
>   final storedData = await dbFunctions.getStoredData('CC-TS-TEST');
>   expect(storedData, isNotEmpty);
>   expect(storedData.first['key'], 'testKey');
> });
> ```

## Connexion WebSocket bidirectionnelle

La tâche fut de gérer une connexion bidirectionnelle via WebSocket en créant des channels pour modifier le temps d’envoi cyclique.

> **Exemple : Envoi d'un message au client (fichier `websocket_server.dart`)**
>
> ```dart
> void sendMessageToClient(String targetId, String message) {
>   final targetClient = _clients[targetId];
>   targetClient?.sink.add(message);
> }
> ```

## Réinscription et gestion des exceptions

Pour gérer les exceptions lors de l’inscription, une regex fut mise en place pour vérifier la validité d’un numéro de série.

> **Exemple : Vérification via regex**
>
> ```dart
> final regExp = RegExp(r'^CC-(TS|YT)-\d{5}$');
> if (!regExp.hasMatch(uniqueId)) {
>   channel.sink.add(jsonEncode({
>     'status': 'error',
>     'message': 'Invalid uniqueId format',
>   }));
> }
> ```

## Authentification avec clé API et UUID

J’ai implémenté une authentification en générant une clé API unique via UUID.

> **Exemple : Génération de la clé API (fichier `database_functions.dart`)**
>
> ```dart
> final apiKey = const Uuid().v4();
> await db.insert('devices', {
>   'uniqueId': uniqueId,
>   'type': type,
>   'apiKey': apiKey,
> });
> ```

## Gestion des données multi-capteurs

Une fonction polyvalente a été créée pour traiter différents types de données envoyées par les capteurs.

> **Exemple : Traitement des données multiples**
>
> ```dart
> if (payload is Map) {
>   final db = await DatabaseFunctions().database;
>   final batch = db.batch();
>   for (final entry in payload.entries) {
>     batch.insert('stored_data', {
>       'uniqueId': uniqueId,
>       'key': entry.key,
>       'value': entry.value.toString(),
>     });
>   }
>   await batch.commit(noResult: true);
> }
> ```

## Interface graphique et actualisation via Streams

L’interface graphique a été facilitée par l’utilisation des Streams pour notifier directement l’UI lors des modifications.

> **Exemple : Notification via StreamController**
>
> ```dart
> final StreamController<void> _databaseChangeController =
>     StreamController.broadcast();
>
> void notifyDatabaseChange() {
>   _databaseChangeController.add(null);
> }
> ```

## Journalisation (Logs)

Une table de logs fut créée afin de tracer les modifications effectuées par le serveur WebSocket.

## Trames Application Client – Capteur



Voici un exemple de trames server / capteur qui transitent via WebSocket. Ces tramens permettent l’enregistrement, l’envoi périodique de données de télémétrie mais aussi la gestion du mode de fonctionnement (actif ou veille).



### Enregistrement du capteur



**Requête envoyée par le capteur :**

```json

 {

   "action": "register",

   "uniqueId": "CC-TS-00001",

   "type": "sensor"

 }

 ```



*Pour un capteur nécessitant authentification :*

```json

 {

   "action": "register",

   "uniqueId": "CC-TS-00001",

   "type": "sensor",

   "username": "user_example",

   "password": "password_example"

 }

 ```



**Réponse du serveur :**

```json

 {

   "status": "success",

   "message": "Sensor connected successfully",

   "apiKey": "<generated_api_key>"

 }

 ```



### Transmission de données de télémétrie



**Envoi de la température :**

```json

 {

   "action": "sendData",

   "uniqueId": "CC-TS-00001",

   "key": "temperature",

   "value": "25.0",

   "type": "sensor",

   "apiKey": "<generated_api_key>"

 }

 ```



**Envoi de l’humidité :**

```json

 {

   "action": "sendData",

   "uniqueId": "CC-TS-00001",

   "key": "humidity",

   "value": "50",

   "type": "sensor",

   "apiKey": "<generated_api_key>"

 }

 ```



### Réglage et mise à jour du mode de fonctionnement



Le capteur envoie, dès son enregistrement, un attribut indiquant son mode initial (actif ou veille) :



```json

 {

   "action": "setAttribute",

   "uniqueId": "CC-TS-00001",

   "key": "mode",

   "value": "active",

   "apiKey": "<generated_api_key>"

 }

 ```

### Changement dynamique du mode de fonctionnement

Grace à une implémentation de messages bidirectionnels, on peut envoyer par l'intérmédiaire du serveur un message à une application de capteur spécifique une demande de changement à la volée du mode de fonctionnement  :



```json

 {

   "action": "changeMode",

   "mode": "sleep"

 }

 ```



A la réception de la commande, l’application capteur met à jour son état interne afin de s'adapteur au nouvel intervalle de transmission des données en redémarrant ses envois cycliques de télémétrie en fonction du nouveau mode.