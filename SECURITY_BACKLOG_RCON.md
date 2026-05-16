# Backlog Issue Draft (Security): Secret-backed RCON rollout

Use this as a separate backlog ticket before merge/deploy:

- [ ] Add a deploy-time secret for RCON in Coolify (no plaintext in repo)
- [ ] Keep `docker-compose.yml` default `EXTRA_PARAMS` free of `+rcon_password`
- [ ] Add/update operator docs so RCON is explicit opt-in only
- [ ] Validate logs/startup output do not print the full RCON value
- [ ] Rotate and replace any previously shared RCON values
