# Playing with a friend (same network or over the internet)

## Same Wi‑Fi / LAN

1. **Host:** Run the game → **Host server**. The window shows something like **Share with friend: 192.168.1.5:8081**. Tell your friend that address.
2. **Friend:** Run the game → **Join game** → enter the host’s IP (e.g. `192.168.1.5`) and port `8081` → **Connect** → enter name → **Join game** with the code the host shares.

## Different networks (internet)

The friend must be able to reach your machine on **port 8081**.

1. **Host:** On your router, forward **TCP (and optionally UDP) port 8081** to your PC’s local IP (the one shown in “Share with friend”).
2. **Your public IP:** Look up your public IP (e.g. search “what is my ip”) and share **`YOUR_PUBLIC_IP:8081`** with your friend.
3. **Friend:** Join game → enter your **public IP** and port **8081** → Connect. If it fails, the host should check firewall (allow the game or port 8081) and port forwarding.

## Sharing the game

- **Option A – Same project:** Send the project folder; your friend opens it in Godot and runs the game (same steps as above).
- **Option B – Export:** In Godot: **Project → Export**, add a preset (e.g. Windows Desktop / macOS / Linux), then **Export Project** or **Export PCK/ZIP**. Share the exported build; your friend runs the executable. They use **Join game** and enter your IP and port as above.

## Quick checklist (host)

- [ ] Run game → Host server  
- [ ] Note the “Share with friend” address (IP:8081)  
- [ ] If friend is on another network: port 8081 forwarded on router to this PC  
- [ ] Firewall allows the game (or port 8081)  
- [ ] Share your IP (local for same network, public for internet) and game code with your friend  

## Quick checklist (friend)

- [ ] Run game → Join game  
- [ ] Enter host’s IP and port (default 8081) → Connect  
- [ ] Enter name → Join game with the code the host sent  
