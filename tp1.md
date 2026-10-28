Partie 1 : Explorer l'API
**1.1** Quelle est la version du moteur Docker ? Quelle est la version de son API ?

Après la commande : dapi GET /version | jq : 
La version du moteur docker : 27.3.1 et celle de l'api : 1.47

**1.2** Avec `/info`, affichez uniquement ces informations, dans un seul objet JSON : le nombre de conteneurs, le nombre de conteneurs en cours d'exécution, le nombre d'images, le système d'exploitation et le nombre de CPU.

Après la commande :  dapi GET /info | jq '{Containers, ContainersRunning, Images, OperatingSystem, NCPU}'
Il y'a 13 conteneurs, 3 en execution, 14 images, Docker destop en OS et 8 en CPU. 
```json 
→ HTTP 200
{
  "Containers": 13,
  "ContainersRunning": 3,
  "Images": 14,
  "OperatingSystem": "Docker Desktop",
  "NCPU": 8
}
```


**1.3** Toujours avec /info, affichez la mémoire totale de la machine en Gio, arrondie à l'entier. Le champ MemTotal est en octets.
Après commande 1 : dapi GET /info | jq  '{MemTotal}'
```JSON
{
  "MemTotal": 8199888896
}
```
Après commande 2 : dapi GET /info | jq '{MemTotal_Gio: ((.MemTotal / (1024 * 1024 * 1024)) | round)}'
```JSON
{
  "MemTotal_Gio": 8
}
```

**1.4** Listez tous les conteneurs, y compris arrêtés, sous la forme d'une ligne par conteneur : nom   état   image.
Après la commande : dapi GET '/containers/json?all=true' | jq -r '.[] | "\( (.Names[0] | ltrimstr("/")) )   \(.State)   \(.Image)"'
```JSON
bt-grafana   running   grafana/grafana:10.4.5
bt-promtail   running   grafana/promtail:2.9.8
bt-suricata   exited   bt-suricata:s3
bt-loki   running   grafana/loki:2.9.8
exam-app-1   exited   exam-app
exam-db-1   exited   postgres:17-alpine
php-app-1   exited   php-app
php-db-1   exited   mysql:latest
compose-app-1   exited   compose-app
compose-db-1   exited   mysql:latest
mysql-container   exited   mysql:latest
youthful_kalam   exited   6b4ce93225fb
dreamy_sanderson   exited   hello-world
```


**1.5** Listez les images présentes (leurs tags), puis affichez la taille totale de toutes les images, en Mo.
Après la commande 1 : dapi GET /images/json | jq -r '.[] | .RepoTags[]?'
```JSON
→ HTTP 2bt-suricata:s3
00mini-app:latest

php-app:latest
compose-app:latest
mysql:latest
nginx:latest
postgres:17-alpine
alpine:latest
exam-app:latest
hello-world:latest
grafana/grafana:10.4.5
grafana/loki:2.9.8
grafana/promtail:2.9.8
```
Après la commande 2 : dapi GET /images/json | jq '(([.[] | .Size] | add) / 1000000) | round'
La taille est : 5445

Partie 2 : le cycle de vie d'un conteneur 
2.1 Télécharger l'image.
La réponse est un flux : une ligne JSON par étape du téléchargement. Pourquoi l'API ne répond-elle pas en un seul bloc ?
Parce le téléchargement prend du temps, et que ca permet alors de suivre les étapes du téléchargement.


**2.2** Créer le conteneur. 
L'id renvoyé : 
"Id":"5612b8640d896d81f4111e26f455cf5ccae0962c11f081ac5bae5031e31f5abc",

Relancez exactement la même commande : quel code obtenez-vous, et que dit le message ?
```JSON
→ HTTP 409{

  "message": "Conflict. The container name \"/web-tp1\" is already in use by container \"5612b8640d896d81f4111e26f455cf5ccae0962c11f081ac5bae5031e31f5abc\". You have to remove (or rename) that container to be able to reuse that name."
}
```

**2.3** Démarrer le conteneur. 
Après la commande : dapi POST /containers/web-tp1/start
Quel code ? Pourquoi la réponse n'a-t-elle pas de corps ? Relancez la même commande : quel code obtenez-vous maintenant, et que signifie-t-il ?

Le code HTTP 204 indique que la requète s'est bien passée, mais qu'il n'y a aucun contenu. Et le code 304 indique que depuis la dernière fois que la requète a été lancée, rien a changé. 


**2.4 Inspecter le conteneur.** Avec `GET /containers/web-tp1/json` et jq, affichez :
- son état (`running`, `exited`…) et sa date de démarrage ;
- le port de la machine associé à son port 80 ;
- ses labels.

Après la commande :
```bash
 dapi GET /containers/web-tp1/json | jq '{
  Etat: .State.Status,
  DateDemarrage: .State.StartedAt,
  Port: .NetworkSettings.Ports["80/tcp"][0].HostPort,
  Labels: .Config.Labels
}'
``` 

```JSON
→ HTTP 200
{
  "Etat": "running",
  "DateDemarrage": "2026-10-26T11:00:08.035571122Z",
  "Port": "8088",
  "Labels": {
    "desktop.docker.io/wsl-distro": "Debian",
    "maintainer": "NGINX Docker Maintainers <docker-maint@nginx.com>",
    "tp": "api-rest"
  }
}
```
Vérifiez que nginx répond, après la commande : curl -s localhost:8088 | head -n 4
```HTML
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

**2.5** Supprimer un conteneur en marche.
Après la commande : dapi DELETE /containers/web-tp1
Quel code ? Pourquoi est-ce le bon code, plutôt que 400 ou 403 ?
Code 409, c'est le bon puisque qu'il renvoie qu'il y'a un conflit, cad qu'on ne peut pas le supprimer car le conteneur tourne encore dans ce cas précis. Donc on ne peut rien faire tant qu'il tourne encore. 

**2.6** Arrêter le conteneur, deux fois.
Après les commandes : 
```bash
dapi POST '/containers/web-tp1/stop?t=5'
dapi POST '/containers/web-tp1/stop?t=5'
``` 

Relevez les deux codes. Que signifie le paramètre t ?
Les 2 codes renvoyés sont 204 et 304. 
Le 204 indique qu'il a bien été arrété donc que la requète s'est bien exécuté. Et le code 304 indique que le conteneur est déja arrété qu'il n'y a pas eu de modification depuis la derniere requète. 
Le paramètre t=5 indique le délai d'attente (5s) laissé au conteneur pour s'arréter. 



**2.7** Supprimer, puis vérifier.
Après la commande : 
```bash
dapi DELETE /containers/web-tp1
dapi GET /containers/web-tp1/json
```

Relevez les deux codes. Que renverrait un deuxième DELETE ? Peut-on dire que DELETE est idempotent ici ?
Le premier est un code 204 et le deuxieme un code 404.
Si on refaisait un DELETE, on aurait un autre 404 puisqu'il est déja supprimé.
Oui on peut dire qu'il est idempotent car après plusieurs suppressions le conteneur n'est plus la. 


Partie 3 : exécuter une commande, lire les logs.

Recréez et démarrez le conteneur `web-tp1` (étapes 2.2 et 2.3).

**3.1 Exécuter une commande.** Un exec se fait en **trois appels** :

```bash
# 1. Créer l'exec
EXEC_ID=$(dapi POST /containers/web-tp1/exec "$(jq -n '{
  Cmd: ["sh", "-c", "nginx -v; head -n 2 /etc/os-release"],
  AttachStdout: true, AttachStderr: true, Tty: true
}')" | jq -r .Id)

# 2. Le lancer et récupérer sa sortie
dapi POST "/exec/$EXEC_ID/start" '{"Detach": false, "Tty": true}'

# 3. Lire son code de sortie
dapi GET "/exec/$EXEC_ID/json" | jq '{ExitCode, Running}'
```
Recommencez avec une commande qui échoue, par exemple ls /nexiste-pas. Quel est le code HTTP de l'étape 2 ? Et le ExitCode de l'étape 3 ? Qu'en concluez-vous sur la différence entre l'API a fonctionné et la commande a réussi ?

Quand j’exécute ls /nexiste-pas, le code HTTP de l’étape 2 est 200 et l’ExitCode de l’étape 3 est 1.

Le code HTTP 200 vient du démon Docker : il signifie que Docker a bien lancé la commande. L’ExitCode vient de la commande elle-même : 0 veut dire qu’elle a réussi, un nombre différent de 0 veut dire qu’elle a échoué.

Je conclus que l’API a fonctionné et la commande a réussi sont deux choses différentes. Ici, l’API a fonctionné (200) mais la commande a échoué (ExitCode 1). Il faut toujours lire l’ExitCode


**3.2** Lire les logs. Générez un peu de trafic, puis lisez les dernières lignes de log.

Les 8 premiers octets forment un en-tête. Que contiennent-ils ? Pourquoi n'apparaissaient-ils pas dans la sortie de l'exec en 3.1 ?
Les 8 premiers octets sont un en-tête. Le 1er octet dit d’où viennent les données (1 = stdout, 2 = stderr). Les 4 derniers octets donnent la taille des données qui suivent. Les autres valent 0.
Ici : 01 00 00 00 00 00 00 61, donc stdout et 97 octets.
Cet en-tête n’apparaissait pas en 3.1 car l’exec avait Tty: true : avec un TTY, stdout et stderr sont mélangés, donc Docker n’a pas besoin de les distinguer. Le conteneur web-tp1 n’a pas de TTY, donc Docker ajoute cet en-tête 


Partie 4 : écrire dockerctl.sh

Test pour le dockerctl.sh
```BASH

pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh run web1 nginx:alpine 8088:80; echo "code=$?"
b4830d79471d
code=0
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh run web1 nginx:alpine 8088:80; echo "code=$?"
erreur : code HTTP 409 : Conflict. The container name "/web1" is already in use by container "b4830d79471d698e1a2dbb357b221f0c3cb229b3d069f986955326c4246b512e". You have to remove (or rename) that container to be able to reuse that name.
code=1
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh run 'web;rm' nginx:alpine; echo "code=$?"
erreur : nom invalide : 'web;rm' (lettres, chiffres, _ . et - uniquement)
code=1
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh ls
NOM                  ETAT       IMAGE                     PORTS
web1                 running    nginx:alpine              8088->80
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh exec web1 nginx -v; echo "code=$?"
nginx version: nginx/1.31.8
code=0
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh exec web1 ls /nexiste-pas; echo "code=$?"
ls: /nexiste-pas: No such file or directory
code=1
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh rm web1; echo "code=$?"
./dockerctl.sh rm web1; echo "code=$?"
web1 : supprimé
code=0
web1 : déjà absent
code=0
pouette@OrdiLea:/mnt/c/Users/leade/api-restM1$ ./dockerctl.sh clean; echo "code=$?"
./dockerctl.sh ls
aucun conteneur du TP
code=0
NOM                  ETAT       IMAGE                     PORTS


```

| Étape | Requête | Code HTTP | Signification |
|---|---|---|---|
| 2.1 | POST /images/create | 200 | OK : la requête est acceptée et Docker commence à renvoyer le flux de progression du téléchargement |
| 2.2 | POST /containers/create | 201 | Created : le conteneur a été créé, la réponse contient son id |
| 2.2 bis | même requête, une seconde fois | 409 | Conflict : le nom est déjà utilisé par le conteneur qui existe |
| 2.3 | POST /containers/{id}/start | 204 | No Content : le conteneur a démarré mais y'a rien dedans |
| 2.3 bis | même requête, une seconde fois | 304 | Not Modified : le conteneur est deja démarré, etat inchangé |
| 2.5 | DELETE sur un conteneur en marche | 409 | Conflict : requête OK, mais il y'a un conflit avec l’état actuel, le conteneur tourne encore |
| 2.6 | POST …/stop | 204 | No Content : le conteneur a été arrêté |
| 2.6 bis | même requête, une seconde fois | 304 | Not Modified : conteneur déjà arrêté, etat inchangé |
| 2.7 | DELETE /containers/{id} | 204 | No Content : le conteneur a été supprimé |
| 2.7 bis | GET /containers/{id}/json après suppression | 404 | Not Found : le conteneur n’existe plus |
| 3.1 | POST /exec/{id}/start d'une commande qui échoue | 200 | OK : Docker a lancé la commande. L’erreur se lit dans l’ExitCode, pas dans le code HTTP. |