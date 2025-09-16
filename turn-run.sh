docker run -d --name coturn --restart unless-stopped \
  --network host \
  -v /etc/letsencrypt/live/matrix.example.site:/certs:ro \
  instrumentisto/coturn \
  -n --no-cli --no-tls --no-dtls \
  --listening-port=3478 \
  --min-port=49152 --max-port=49999 \
  --realm=example.site \
  --use-auth-secret --static-auth-secret=CHANGE_ME_SHARED_SECRET \
  --no-tcp-relay \
  --external-ip="$(curl -s ifconfig.me)" \
  --cert=/certs/fullchain.pem --pkey=/certs/privkey.pem
