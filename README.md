# Inception-of-Things

> Mise en place d'une infrastructure Kubernetes de bout en bout : provisionnement de VMs avec **Vagrant**, clusters **K3s** et **K3d**, exposition d'applications via **Ingress**, et déploiement continu **GitOps** avec **Argo CD**.

Projet réalisé dans le cadre du cursus 42 (administration système / DevOps).

---

## Ce que ce projet démontre

| Compétence | Mise en pratique |
|---|---|
| **Infrastructure as Code** | VMs entièrement décrites dans des `Vagrantfile` et des scripts de provisioning, reproductibles en une commande |
| **Orchestration de conteneurs** | Cluster Kubernetes multi-nœuds (1 server + 1 agent) avec K3s |
| **Réseau Kubernetes** | Services, Ingress (Traefik), routage HTTP par hostname, réseau overlay Flannel |
| **Haute disponibilité** | Déploiement avec plusieurs réplicas et répartition de charge |
| **GitOps / CD** | Déploiement automatique depuis un dépôt Git avec Argo CD (sync, self-heal, prune) |
| **Automatisation** | Scripts Bash d'installation complète (Docker, K3d, kubectl, Argo CD) |
| **Diagnostic** | Résolution de problèmes de virtualisation imbriquée, de réseau, de DNS et de permissions |

---

## Notions abordées

### Virtualisation et conteneurs
- **VM vs conteneur** : une VM embarque un OS complet avec son kernel, un conteneur partage celui de l'hôte (plus léger, démarrage quasi instantané).
- **Vagrant** : outil qui crée et configure des VMs à partir d'un fichier texte (`Vagrantfile`). Les notions de *box* (image de base), *provider* (hyperviseur : libvirt/KVM) et *provisioning* (script lancé à la création) sont mises en œuvre.

### Kubernetes
- **Cluster** : ensemble de machines orchestrées par Kubernetes, avec un *control plane* (qui décide) et des *workers* (qui exécutent).
- **Pod** : plus petite unité déployable, contient un ou plusieurs conteneurs.
- **Deployment / ReplicaSet** : maintient en permanence le nombre de pods désiré (réplicas), relance les pods défaillants, gère les mises à jour.
- **Service** : point d'accès réseau stable vers un groupe de pods (leurs IP changent à chaque recréation).
- **Ingress** : règles de routage HTTP vers les Services, ici selon le header `Host`.
- **Namespace** : isolation logique des ressources au sein d'un cluster.

### K3s et K3d
- **K3s** : distribution Kubernetes légère (un seul binaire) qui embarque Traefik, CoreDNS, Flannel et containerd.
- **K3d** : exécute K3s dans des conteneurs Docker, idéal pour créer rapidement un cluster local.

### GitOps et déploiement continu
- **GitOps** : le dépôt Git est la source de vérité de l'état du cluster.
- **Argo CD** : surveille un dépôt Git et synchronise automatiquement le cluster avec son contenu. Un push suffit pour mettre à jour une application.

---

## Architecture

```
Partie 1                          Partie 2
┌──────────────────────┐          ┌─────────────────────────────┐
│ junguyenS (server)   │          │ junguyenS                   │
│ 192.168.56.110       │◄────────►│  Traefik (Ingress)          │
└──────────────────────┘  token   │   ├─ app1.com → app-one     │
┌──────────────────────┐          │   ├─ app2.com → app-two (x3)│
│ junguyenSW (agent)   │          │   └─ autre    → app-three   │
│ 192.168.56.111       │          └─────────────────────────────┘
└──────────────────────┘

Partie 3
GitHub ──sync──► Argo CD (namespace argocd) ──déploie──► App (namespace dev)
   ▲                         cluster K3d (Docker)
   └── push (v1 → v2)
```

---

## Structure du dépôt

```
.
├── p1/   # K3s et Vagrant : cluster de 2 VMs
├── p2/   # K3s et 3 applications derrière un Ingress
└── p3/   # K3d et Argo CD (GitOps)
```

Chaque dossier contient ses `Vagrantfile` (p1, p2), `scripts/` et `confs/`.

---

## Détail des parties

### Partie 1 : cluster K3s avec Vagrant

Deux VMs créées par Vagrant (1 CPU, 1024 Mo de RAM chacune), formant un cluster K3s.

| Machine | Hostname | IP | Rôle |
|---|---|---|---|
| 1 | `junguyenS` | `192.168.56.110` | Server (control plane) |
| 2 | `junguyenSW` | `192.168.56.111` | Agent (worker) |

Points techniques :
- Connexion SSH sans mot de passe via les clés générées par Vagrant.
- K3s est forcé à utiliser l'interface du réseau privé (`--node-ip`, `--flannel-iface`) pour que server et agent communiquent.
- L'agent rejoint le cluster avec un token partagé ; les VMs démarrent en séquence (`--no-parallel`) pour que le server soit prêt avant l'agent.

```bash
cd p1
vagrant up --no-parallel
vagrant ssh junguyenS
kubectl get nodes -o wide
```

### Partie 2 : trois applications et un Ingress

Une VM avec trois applications web, accessibles selon le header `Host` de la requête.

| Host | Application |
|---|---|
| `app1.com` | app-one |
| `app2.com` | app-two (**3 réplicas**) |
| autre | app-three (route par défaut) |

Chaque application = un **Deployment** + un **Service** ; un **Ingress** Traefik route vers le bon Service.

```bash
cd p2
vagrant up
vagrant ssh junguyenS

kubectl get all
kubectl get ingress
curl -H "Host: app1.com" 192.168.56.110
curl -H "Host: app2.com" 192.168.56.110
curl 192.168.56.110            # app3 par défaut
```

### Partie 3 : K3d et Argo CD

Cluster K3d avec Argo CD, sans Vagrant. Argo CD surveille un dépôt GitHub public ([junguyen-iot-app](https://github.com/jln-nguyen/junguyen-iot-app)) et déploie l'application `wil42/playground` dans le namespace `dev`.

Un script Bash installe tout automatiquement : Docker, K3d, kubectl, création du cluster et des namespaces (`argocd`, `dev`), installation d'Argo CD, affichage du mot de passe admin.

```bash
cd p3
sudo bash scripts/script-init.sh

# Interface Argo CD : https://localhost:8080 (user: admin)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Application
kubectl port-forward -n dev svc/wil-playground 8888:8888
```

**Démonstration du déploiement continu :**
1. L'application tourne en `v1` : `curl localhost:8888` → `{"status":"ok", "message": "v1"}`
2. Modification de `v1` en `v2` dans le dépôt Git, commit et push
3. Argo CD détecte le changement et redéploie automatiquement
4. `curl localhost:8888` → `{"status":"ok", "message": "v2"}`

---

## Prérequis

- Linux avec virtualisation matérielle (VT-x / AMD-V)
- [Vagrant](https://developer.hashicorp.com/vagrant) et le plugin `vagrant-libvirt` (parties 1 et 2)
- Droits `sudo` (partie 3)

## Technologies

`Vagrant` · `libvirt/KVM` · `Kubernetes` · `K3s` · `K3d` · `Docker` · `Traefik` · `Argo CD` · `kubectl` · `Bash` · `Git / GitHub`
