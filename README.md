# Matrix server + basics

- Run the compose file for matrix setup, run turn-run.sh for 1-on-1 calls and video chat, then add the code below to homeserver.yaml in Synapse container

docker-compose.yml (Synapse + Postgres + Element)

Create a folder and save, change all the instances of "example.com" add your domain:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: change_me
      POSTGRES_DB: synapse
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  synapse:
    image: ghcr.io/element-hq/synapse:v1.135.2
    depends_on:
      db:
        condition: service_healthy
    environment:
      SYNAPSE_SERVER_NAME: example.com 
      SYNAPSE_REPORT_STATS: "yes"
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    volumes:
      - synapse-data:/data
    # EXPOSE PLAIN HTTP ONLY to localhost for nginx
    ports:
      - "127.0.0.1:8008:8008"
    restart: unless-stopped

  element:
    image: vectorim/element-web:v1.11.111
    depends_on:
      - synapse
    volumes:
      - ./element/config.json:/app/config.json:ro
    # serve Element via your existing nginx on a local port
    ports:
      - "127.0.0.1:8081:80"
    restart: unless-stopped

volumes:
  db-data:
  synapse-data:
```

`element/config.json`:

```json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://example.com",
      "server_name": "example.com"
    }
  },
  "disable_custom_urls": true
}
```

## 2) Generate Synapse config (one time)

```bash
mkdir -p element
docker compose up -d db

# generate homeserver.yaml in the synapse-data volume
docker run --rm -it \
  -e SYNAPSE_SERVER_NAME=example.com \
  -e SYNAPSE_REPORT_STATS=yes \
  -v $(docker volume inspect --format '{{ .Mountpoint }}' $(basename $(pwd))_synapse-data):/data \
  ghcr.io/element-hq/synapse:v1.135.2 generate
```

- Edit `/data/homeserver.yaml` inside that volume to point at Postgres and **HTTP on 8008**:

```yaml
database:
  name: psycopg2
  args:
    user: synapse
    password: change_me
    database: synapse
    host: db
    cp_min: 5
    cp_max: 10

listeners:
  - port: 8008
    type: http
    tls: false
    bind_addresses: ['127.0.0.1']
    x_forwarded: true
    resources:
      - names: [client, federation, media]
        compress: false
```

Bring it up:

```bash
docker compose up -d
```

- Smoke test (must be **200 OK**):

```bash
curl -I http://127.0.0.1:8008/_matrix/client/versions
```

- Add user with the adduser.sh script, put in your correct container name.

- Code to add to homeserver.yaml in Synapse container, change the domains and secrect here and run command in turn-run.sh:
```bash
turn_uris:
  - "turn:matrix.example.com:3478?transport=udp"
  - "turn:matrix.example.com:3478?transport=tcp"
  # uncomment if you enabled TLS on 5349:
  # - "turns:matrix.example.com:5349?transport=tcp"

turn_shared_secret: "CHANGE_ME_SHARED_SECRET"
turn_user_lifetime: 864000        # 10 days, common default
turn_allow_guests: false
```
