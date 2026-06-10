# CS2 Server on ARM64 using FEX
Thanks to [sa-shiro/Satisfactory-Dedicated-Server-ARM64-Docker](https://github.com/ayayrom/Satisfactory-Dedicated-Server-ARM64-Docker), they inspired this project.

---

## Getting Started

1. **Make directory**:  
   by doing this: `mkdir cs2-server && cd cs2-server`

2. **Docker Compose setup**:
   Paste this in the directory's docker-compose.yml:
```
services:
  cs2-server:
    build:
      context: https://github.com/ayayrom/CS2-Server-ARM-Docker.git#main
      dockerfile: Dockerfile 
      # change to "Dockerfile.generic" if you are not using Oracle Ampere

    container_name: 'cs2-server'
    ports:
      - '27015:27015/udp'
      - '27015:27015/tcp'
    restart: 'unless-stopped'
    # change if you don't want cs2 hogging compute
    ulimits:
      nice:
        soft: -20
        hard: -20
    environment:
      STEAM_GAMESERVER_API: ${STEAM_GAMESERVER_API:-}
      STARTUP_MAP: ${STARTUP_MAP:-de_dust2}

      CPU_CORE_COUNT: ${CPU_CORE_COUNT:-3}
      SERVER_NICENESS: ${SERVER_NICENESS:-0}
      PUID: ${PUID:-1001}
      PGID: ${PGID:-1001}

      ALWAYS_UPDATE_ON_START: ${ALWAYS_UPDATE_ON_START:-true}
      ENABLE_MODDING: ${ENABLE_MODDING:-false}
      # CHANGE DOTNET TO 0 IF USING MODDING
      DOTNET_EnableWriteXorExecute: 1
      MMS_URL: ${MMS_URL:-}
      CSS_URL: ${CSS_URL:-}

      EXTRA_PARAMS: >
        -nojoy
        -nohltv
        +engine_no_focus_sleep 0
        +fps_max 64
        +sv_hibernate_when_empty 0
    volumes:
      - './cs2-data:/cs2-data'
      - './fex-data:/home/steam/.fex-emu'
    stdin_open: true
    tty: true
    entrypoint: /home/steam/init-server.sh
```

3. **Port Access and Forwarding**:  
   On your router (or Oracle Cloud Security List), open the port 27015 TCP/UDP (or respective to your other port choosing). They are the default ports for a CS2 server.

   DOCKER WILL BYPASS UFW, so you will not need for any firewall rules.

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

However, it works.

I have also tried to compress [zThundy/CS2-Server-on-ARM](https://github.com/zThundy/CS2-Server-on-ARM)'s Box64 implementation into a docker compose file, but it was riddled with segmentation faults left and right. When Box64 comes to be more stable, I will attempt it again, but for now, FEX will do.

[FEX](https://github.com/FEX-Emu/FEX) hella goated, yall should check it out
