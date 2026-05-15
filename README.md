# CS2 Server on ARM64 using FEX
Major thanks to [sa-shiro/Satisfactory-Dedicated-Server-ARM64-Docker](https://github.com/ayayrom/Satisfactory-Dedicated-Server-ARM64-Docker), they figured the hardest part out.

---

## Getting Started

1. **Download or Clone Repository**:  
   You can download this repository by either the code button above or using  
   `git clone https://github.com/ayayrom/CS2-ARM64-Server-FEX.git`
   Next, you'll want to cd into it using this: `cd CS2-ARM64-Server-FEX`

2. **Setting up file system**:  
   **WIP, will do something about the security later**  
   - First, make the directories `cs2-data` and `fex-data`. You can accomplish this by doing `mkdir -p cs2-data fex-data`.
   - Second, give the directories permission by 
     - Using `chmod`:
       ```
       sudo chmod 777 cs2-data
       sudo chmod 777 fex-data
       sudo chmod 777 init-server.sh
       sudo chmod +x init-server.sh
       ```
     - Using `chown` (replace **USER_ID:GROUP_ID** with the desired user's IDs, for example, `1000:1000`):
       ```
       sudo chown -R USER_ID:GROUP_ID cs2-data
       sudo chown -R USER_ID:GROUP_ID fex-data
       ```
       (On Oracle Cloud Infrastructure (OCI), by default, the user with the ID `1000:1000` is `opc`. However, since this user is primarily intended for the setup process, it is advisable to utilize the `ubuntu` user with IDs `1001:1001`)

3. **Build the Docker Image**:  
   This section will take about ~15 minutes to compile from source. If it goes beyond that, check to make sure the compilation isn't stuck.  
   Run the command **IF YOU ARE USING ORACLE CLOUD'S AMPERE**:
   ```
   sudo docker build -t cs2-arm64 -f Dockerfile .
   ```
   Run the command **IF YOU ARE USING SOMETHING ELSE**:
   ```
   sudo docker build -t cs2-arm64 -f Dockerfile.generic .
   ```

4. **Run the Docker Image**:  
   To run the docker image, run the command:
   ```
   sudo docker compose up -d
   ```
   If you want to follow the logs after it is running, run the command:
   ```
   sudo docker compose logs -f
   ```

5. **Port Access and Forwarding**:  
   On your router (or Oracle Cloud Security List), open the ports 27015 TCP and UDP. 27015 is the default port for Counter-Strike 2 servers.  

   You will also need to allow the port over the firewall. This can be done however your system is built. For this example, I will be showcasing an example of UFW. Run the command to allow port 27015/tcp and udp to communicate to the outside world:
   ```
   sudo ufw allow 27015/tcp
   sudo ufw allow 27015/udp
   sudo ufw reload
   ```

Once you finish step 5, congrats! The server is now ready to be used. 

# Modifying Docker Compose Config
- If you want to change the port to some other port, you can add -port \<port> to the EXTRA_PARAMS and change the Docker Compose ports as well.
- All EXTRA_PARAMS can be found by googling what you need. I cannot help you and will not help you on finding all the extra parameters that can be added. The current EXTRA_PARAMS is good enough for the server to run.
- Currently, installing MetaMod and CounterStrikeSharp is available. This will change in the future when I can dedicate some time to polishing this project.
- If you are installing plugins onto the server, you MUST disable ALWAYS_UPDATE_ON_START and enable INSTALL_MODDING. You must also change DOTNET_EnableWriteXorExecute to 0.
- You can find your STEAM_GAMESERVER_API by visiting [Valve's GameServer page](https://steamcommunity.com/dev/managegameservers). Once you go in there, you can create a new game server account by putting 730 in the App ID textbox, and whatever you want for the memo. I recommend putting `cs2-arm server` in the memo.
- I am still learning about docker compose, so this may be very insecure and I am sorry about that. 

# Common Questions
- **Q**: Can the server handle 10 players?
  - **A**: In my experience, I have not hosted a 10man yet. I have tested it with bot 10v10s, and it was spitting out `Slow Server Frame` almost every second. I have used it for a 1v1 on a custom workshop map. It was fine with almost no noticeable lag.
- **Q**: How do I install and play custom workshop maps?
  - **A**: In your linux terminal (not Counter-Strike!), run 
    ```
    sudo docker attach cs2-server
    ```
    If the server hasn't finished initializing, wait for it to finish until the server is running properly. When it is finished, input this command:
    ```
    host_workshop_map <workshop ID>
    ``` 
    If you don't know how to find workshop ID's, Google is your best friend.
    To exit out of the attached terminal, do CTRL+P and CTRL+Q in that order.
- **Q**: Can I optimize the server?
  - **A**: Yes, however, I have no idea if these options are secure for your system. I am currently using them, but I do not recommend these options if you value security. Input this json in fex-data/Config.json:
    ```
    {
    "Config": {
      "SilentLog": "0",
      "EnableCodeCacheValidation": "0",
      "X87ReducedPrecision": "1",
      "StrictInProcessSplitLocks": "0",
      "DisableTelemetry": "1",
      "EnableCodeCachingWIP": "0",
      "DynamicL1Cache": "0",
      "HalfBarrierTSOEnabled": "0",
      "KernelUnalignedAtomicBackpatching": "1",
      "DisableL2Cache": "0",
      "MaxInst": "5000",
      "MemcpySetTSOEnabled": "0",
      "RootFS": "Ubuntu_22_04",
      "Multiblock": "1",
      "VectorTSOEnabled": "0",
      "TSOEnabled": "0",
      "SMCChecks": "1"
      },
    "ThunksDB": {}
    }
    ```
- **Q**: My question isn't here!
  - **A**: If your question isn't here, visit the issues page and make an issue about it. I will add your question here if it already isn't here.

# Extra Ramblings
To be honest, a lot of GPT was used to make this project. Most of the time, when I didn't know something, I had it research things for me. This included the majority of the Dockerfile, the optimization of the FEX-Emulator, the parts including FEXRootFSFetcher, and docker compose patch for CounterStrikeSharp. I did not have the knowledge or the time for learning the FEX-Emulator properly.

However, it works. And that I am glad about. And I hope that this works for you, otherwise this was all for naught.

I have also tried to compress [zThundy/CS2-Server-on-ARM](https://github.com/zThundy/CS2-Server-on-ARM)'s Box64 implementation into a docker compose file, but it was riddled with segmentation faults left and right. When Box64 comes to be more stable, I will attempt it again, but for now, FEX will do.

---

# CS2 Dedicated Server – Debugging & Setup Notes

> Oracle Cloud (OCI) · Coolify · Host: `141.147.52.165`

---

## Architektur

```
Internet
   │
   ▼
Oracle VCN Security List       ← Outer Door (Cloud-Level)
   │
   ▼
Ubuntu Host (141.147.52.165)
   │  iptables INPUT chain      ← Inner Door (OS-Level)
   │
   ▼
docker-proxy (0.0.0.0:27015)   ← Port Bridge (Userspace)
   │
   ▼
cs2-server Container (10.0.7.x:27015)
```

---

## Coolify App-Konfiguration

- **UUID:** `ggbxz48a0bltfqqb0y2nhlbd`
- **Build Pack:** `dockercompose`
- **Proxy/Traefik:** deaktiviert (keine Traefik-Labels)
- **Network Mode:** Bridge (custom Coolify-Netzwerk)
- **Server Name (A2S):** `SACHSENPOWER`

### docker-compose Ports (korrekt konfiguriert ✓)
```yaml
ports:
  - "27015:27015/udp"
  - "27015:27015/tcp"
  - "27020:27020/udp"
  - "26900:26900/udp"
  - "27005:27005/udp"
```

---

## Debugging-Geschichte

### Problem: `Sent: 21 pkts, Recv: 0 pkts`
Classic "Oracle Double-Lock" – zwei Firewalls blockieren gleichzeitig.

---

## Fix 1 – iptables (OS-Ebene) ✅ ERLEDIGT

Oracle-Instanzen kommen mit einem restriktiven INPUT REJECT als Regel 6.
Docker-proxy lauscht auf dem Host → Traffic geht durch INPUT, nicht FORWARD.

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 27015 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 27015 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 27020 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 26900 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 27005 -j ACCEPT
sudo netfilter-persistent save
```

**Ergebnis:** Rules 6–10 in INPUT chain, persistent über Reboots.

---

## Fix 2 – Oracle VCN Security List ⚠️ MANUELL IM OCI CONSOLE

**Wo:** Networking → Virtual Cloud Networks → VCN → Security Lists → Default Security List

**Bug:** Quellportbereich war fälschlicherweise auf den gleichen Port gesetzt (z.B. `27015 → 27015`).
CS2-Clients verbinden sich von einem zufälligen Ephemeral-Port → Oracle hat jeden Packet gedroppt.

### Korrekte Ingress-Regeln:

| Zustandslos | Quelle | Protokoll | **Quellport** | Zielport | Beschreibung |
|-------------|--------|-----------|--------------|----------|-------------|
| Nein | 0.0.0.0/0 | UDP | **Alle** | 27015 | CS2 Game UDP |
| Nein | 0.0.0.0/0 | TCP | **Alle** | 27015 | CS2 RCON/Steam TCP |
| Nein | 0.0.0.0/0 | UDP | **Alle** | 27020 | CS2 SourceTV |
| Nein | 0.0.0.0/0 | UDP | **Alle** | 26900 | Steam LAN |
| Nein | 0.0.0.0/0 | UDP | **Alle** | 27005 | CS2 Client |

> **Wichtig:** `Quellportbereich = Alle` – nicht den Zielport eintragen!

---

## Verifikation ohne CS2-Client

```python
# A2S_INFO Steam Server Query (lokal auf dem Host ausführen)
python3 -c "
import socket
query = b'\xFF\xFF\xFF\xFF\x54Source Engine Query\x00'
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5)
    sock.sendto(query, ('127.0.0.1', 27015))
    data, _ = sock.recvfrom(4096)
    if data[4:5] == b'\x41':
        challenge = data[5:9]
        sock.sendto(b'\xFF\xFF\xFF\xFF\x54Source Engine Query\x00' + challenge, ('127.0.0.1', 27015))
        data, _ = sock.recvfrom(4096)
    print('OK' if data[4:5] == b'\x49' else 'FAIL', data[:32].hex())
except (socket.timeout, OSError) as e:
    print('FAIL', str(e))
finally:
    try:
        sock.close()
    except Exception:
        pass
"
```

**Erwartete Antwort:** Server-Name `SACHSENPOWER`, Map `de_dust2`, AppID `730`

### Externer Test (vom lokalen Rechner):
```bash
python3 -c "
import socket
query = b'\xFF\xFF\xFF\xFF\x54Source Engine Query\x00'
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(5)
sock.sendto(query, ('141.147.52.165', 27015))
data, _ = sock.recvfrom(4096)
print('OK' if data[4:5] in (b'\x49', b'\x41') else 'FAIL', data[:32].hex())
"
# Wenn Timeout → Oracle Security List blockiert noch
# Wenn Antwort → Server vollständig erreichbar
```

---

## Downtime bei Deployments vermeiden (Plan)

| Stufe | Maßnahme | Aufwand | Wirkung |
|-------|----------|---------|---------|
| 1 | Env-Vars direkt in Coolify ändern (kein Rebuild) | Sofort | Mittel |
| 2 | Pre-built Image → Registry → Coolify pull statt build | 1–2h | Hoch |
| 3 | RCON-Warning vor Restart (`say "Restart in 2min"`) | 30min | Spieler-freundlich |
| 4 | Blue-Green (zweiter Container, Port-Swap) | Komplex | Zero-Downtime |

---

## Port-Referenz CS2

| Port | Protokoll | Verwendung |
|------|-----------|------------|
| 27015 | UDP + TCP | Haupt-Gameport (Connect + RCON) |
| 27020 | UDP | SourceTV / HLTV |
| 27005 | UDP | CS2 Client-Port |
| 26900 | UDP | Steam LAN Discovery |
