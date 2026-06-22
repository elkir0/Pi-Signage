# mosquitto/certs — TLS for the 8883 listener

The 8883 listener serves two consumers: fleet-api's privileged client (in-host)
and, later, CT101 fronting `relay.zaforge.com`. Two strategies:

## RECOMMENDED — Let's Encrypt via CT101 (matches the public hostname)
CT101 already runs certbot + OVH DynHost and holds the DNS for the OVH zones,
so adding `relay.zaforge.com` there is the lowest-friction, auto-renewing path.

  # GATED (CT101) — one-time issuance on CT101 (10.10.10.101):
  pct exec 101 -- certbot certonly --nginx -d relay.zaforge.com
  # -> /etc/letsencrypt/live/relay.zaforge.com/{fullchain.pem,privkey.pem}

  # Copy to VM600 on issue + each renewal (deploy hook). server.crt = fullchain,
  # ca.crt = the LE chain (isrgrootx1). fleet-api verifies the broker with ca.crt.
  pct exec 101 -- cat /etc/letsencrypt/live/relay.zaforge.com/fullchain.pem \
    | ssh deploy@10.10.10.160 'cat > /home/deploy/zaforge-relay/mosquitto/certs/server.crt'
  pct exec 101 -- cat /etc/letsencrypt/live/relay.zaforge.com/privkey.pem \
    | ssh deploy@10.10.10.160 'cat > /home/deploy/zaforge-relay/mosquitto/certs/server.key'
  # CA used to verify the SERVER cert (LE chain). For fleet-api, point
  # MQTT_CA_FILE at the LE root; or set rejectUnauthorized w/ system CAs.
  curl -s https://letsencrypt.org/certs/isrgrootx1.pem \
    | ssh deploy@10.10.10.160 'cat > /home/deploy/zaforge-relay/mosquitto/certs/ca.crt'

  # Add a certbot --deploy-hook on CT101 that re-runs the two copies above so
  # renewals propagate automatically (mirrors the existing CT101 cert hooks).

## FALLBACK — self-signed CA (pure in-tunnel, no public name)
Use only if 8883 stays strictly host-internal (fleet-api<->broker) and you do
not front it via CT101. Generate a tiny CA + a server cert for IP 10.10.10.160:

  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
    -subj '/CN=ZaForge Relay CA' -out ca.crt
  openssl genrsa -out server.key 2048
  openssl req -new -key server.key -subj '/CN=10.10.10.160' -out server.csr
  printf 'subjectAltName=IP:10.10.10.160,DNS:relay.zaforge.com' > san.ext
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days 825 -sha256 -extfile san.ext -out server.crt
  chmod 600 server.key

fleet-api then loads ca.crt as MQTT_CA_FILE and the SAN must include whatever
host it dials (we dial mqtts://10.10.10.160:8883, so SAN IP:10.10.10.160).

NOTE: the in-tunnel agent path (1883 on 10.70.0.1) needs NO TLS — WireGuard
provides confidentiality (CONTRACT). TLS is only the 8883 admin/service plane.
