# GitLab EE No Timeout

GitLab EE Trial Removal &amp; Auto-upgrade

> Tested on GitLab EE 18.5.1

## How to run

### Requirements

This generator only works with Linux (prefer Ubuntu LTS)

Furthermore, these following packages should be installed

```bash
bash
jq
openssl
xxd
```

Also, you may need to access [GitLab Self-managed Instance trial](https://about.gitlab.com/free-trial/?hosted=self-managed) to obtain the trial key.

### Using current instance

```bash
chmod +x ./run.sh && ./run.sh
```

Once the diaglog appear, paste your activation token you obtained from GitLab.com (can be in email, please check spam folder too).

### Using `docker` compose

```bash
docker build -t glee:latest .
docker run --rm -it glee:latest /app/run.sh
```

Once the diaglog appear, paste your activation token you obtained from GitLab.com (can be in email, please check spam folder too).

### Apply the license

Once done, you have to replace with the public key in `/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub` with that `run.sh` display after the generation is completed, and don't forget to run these following command to restart GitLab

```bash
gitlab-ctl reconfigure
gitlab-ctl restart
```

Once the GitLab is restarted, visit the **Admin Area > Settings > Add License**, and paste the license you just generated.
