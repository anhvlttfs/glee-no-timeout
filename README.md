# GitLab EE No Timeout

GitLab EE Trial Removal &amp; Auto-upgrade

> Tested on GitLab EE 18.6

## How to run

### Requirements

This generator only works with Linux (prefer Ubuntu LTS)

Furthermore, these following packages should be installed

- `bash`
- `jq`
- `openssl`
- `xxd`

### Using current instance

```bash
chmod +x ./run.sh && ./run.sh
```

### Using `docker` compose

```bash
docker build -t glee:latest .
docker run --rm -it glee:latest /app/run.sh
```

### Apply the license

Once done, you have to replace with the public key in `/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub` with that `run.sh` display after the generation is completed, and don't forget to run these following command to restart GitLab

```bash
gitlab-ctl reconfigure
gitlab-ctl restart
```

Once the GitLab is restarted, visit the **Admin Area > Settings > Add License**, and paste the license you just generated.
