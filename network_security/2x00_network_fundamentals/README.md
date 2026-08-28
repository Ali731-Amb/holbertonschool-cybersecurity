# Network Fundamentals — The Blind Auditor

`network_security/2x00_network_fundamentals`

Audit d'une infrastructure réseau sans documentation, en ligne de commande uniquement.
Le projet construit, task après task, une boîte à outils d'arithmétique IP, puis l'utilise pour
cartographier une topologie inconnue à partir de la table de routage et du cache ARP.

## Contexte

L'ancien administrateur réseau est parti sans transmettre. Les schémas sont périmés, le plan
d'adressage est inconnu, le nombre de sous-réseaux n'est documenté nulle part. Le seul point
d'entrée est un accès shell sur un poste Linux connecté au réseau.

Aucun outil graphique. Pas de solution de cartographie. Le shell, et la compréhension du
fonctionnement réel des réseaux.

## Objectifs

- Convertir décimal ↔ binaire et manipuler les adresses au niveau du bit
- Calculer Network ID, adresse de broadcast et plage d'hôtes utilisables
- Appliquer le VLSM pour proposer une segmentation cohérente
- Lire une table de routage et un cache ARP pour reconstruire une topologie
- Déterminer le chemin d'un paquet d'une source vers une destination

## Environnement

- Kali Linux, ParrotOS ou Ubuntu 22.04+
- Scripts Bash, première ligne exactement `#!/bin/bash`
- Chaque script fait exactement 2 lignes (`wc -l` doit afficher 2)
- Scripts exécutables (`chmod +x`)
- Chaînage par `;`, `&&`, `||`, `|` ; boucles écrites en ligne

## Tasks

### 0. The Paper Byte

Calibrage mental avant toute automatisation : conversion manuelle en binaire 8 bits.

Les valeurs demandées ne sont pas arbitraires — ce sont les briques des masques de sous-réseau.
Le nombre de bits à `1` dans l'octet donne directement la valeur `n` de la notation CIDR.

| Décimal | Binaire 8 bits | Bits à 1 | Préfixes CIDR correspondants |
|---------|----------------|----------|------------------------------|
| 128     | `10000000`     | 1        | /1, /9, /17, /25             |
| 192     | `11000000`     | 2        | /2, /10, /18, /26            |
| 224     | `11100000`     | 3        | /3, /11, /19, /27            |
| 240     | `11110000`     | 4        | /4, /12, /20, /28            |
| 255     | `11111111`     | 8        | /8, /16, /24, /32            |

**Méthode employée (soustractive).** Un octet est une somme de poids fixes :

```
128  64  32  16  8  4  2  1
```

En partant du poids le plus fort, pour chaque position : si le poids tient dans le reste à
représenter, on écrit `1` et on le soustrait ; sinon on écrit `0`. Le reste doit valoir 0
après les huit positions.

**Ce que la task démontre.** Ces cinq valeurs partagent une propriété : leurs bits à `1` sont
contigus et alignés à gauche. C'est la définition même d'un masque valide — la frontière entre
partie réseau et partie hôte étant unique, un masque ne bascule qu'une fois, de `1` vers `0`.
Une valeur comme `170` (`10101010`) est donc légale dans une adresse, jamais dans un masque.

Il n'existe que neuf valeurs possibles pour un octet de masque :
`0, 128, 192, 224, 240, 248, 252, 254, 255`.

### 1. The Encoder (`1-dec2bin.sh`)

Automatisation de la conversion décimale → binaire 8 bits.

```bash
$ ./1-dec2bin.sh 10
00001010
```

*(en cours)*

## Auteur

Alison Amblard — Holberton School, Cybersecurity.
