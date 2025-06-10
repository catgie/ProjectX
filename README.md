# ProjectX

Ce projet contient une application iOS permettant de communiquer avec des 
écouteurs via Bluetooth Low Energy (BLE). Les sources se trouvent dans le 
dossier `ABMate_iOS_Source_230620_6c9d80a`.

## Fonctionnement général du protocole BLE

L'application utilise un gestionnaire Bluetooth (`BluetoothManager`) basé sur 
CoreBluetooth. Il recherche les périphériques, se connecte et transmet les 
commandes via un service propriétaire. Les paquets échangés suivent un format 
`Request/Response` ou `TLV` (Type-Length-Value) défini dans le module
`DeviceManager`.

Chaque commande envoie des octets particuliers et attend une réponse dont la 
structure est décrite dans `DeviceCommManager`. Les informations récupérées
(par ex. niveau de batterie, égaliseur, ANC...) sont exposées via des
`BehaviorRelay` afin d'être observées dans l'interface utilisateur.

## Intégration dans une autre application

1. Copier le dossier `DeviceManager` ainsi que les utilitaires présents dans
   `ABMate/` (notamment `BluetoothManager` et les ViewModels).
2. Ajouter les dépendances nécessaires (RxSwift, SnapKit, etc.).
3. Initialiser `BluetoothManager.shared` puis utiliser les méthodes de
   `DeviceRepository` pour scanner et se connecter aux écouteurs.
4. Utiliser `DeviceCommManager` pour envoyer des requêtes spécifiques selon le
   protocole (exemples dans `ViewModels`).
5. Observer les valeurs publiées pour mettre à jour l'interface.

## Exécution

Ouvrez le projet Xcode contenu dans `ABMate.xcworkspace` puis lancez
l'application sur un appareil iOS disposant du Bluetooth.
