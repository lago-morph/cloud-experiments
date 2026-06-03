# Azure PostgreSQL + Grafana monitoring demo

A self-contained proof of concept that:

1. Uses **Terraform** to create a minimum-spec, burstable **Azure Database for
   PostgreSQL – Flexible Server** (`B_Standard_B1ms`, 32 GiB).
2. Runs two containers via **docker-compose**:
   - **`grafana-stack`** — Grafana Alloy (collector) + Grafana Mimir (metrics
     store) + Grafana (dashboards) in one image, with a pre-provisioned
     dashboard showing **database storage** and **queries per second (1-minute
     rate)**.
   - **`db-load`** — runs a small query batch against the `postgres` management
     database once every 5 minutes to drive the metrics.

```
azure/pg-grafana/
├── terraform/        # creates the managed Postgres instance
├── stack/            # grafana-stack image (Alloy + Mimir + Grafana)
├── load/             # db-load image (psql in a loop)
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Prerequisites (on your laptop)

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2 (`docker compose`)
- An Azure subscription and a **service principal** (app registration) with
  rights to create a resource group and a PostgreSQL flexible server
  (Contributor on the subscription is sufficient).

---

## Step 1 — Clone the repo

```bash
git clone https://github.com/lago-morph/cloud-experiments.git
cd cloud-experiments/azure/pg-grafana
```

## Step 2 — Set Azure credentials as environment variables

Terraform's `azurerm` provider reads these `ARM_*` variables, so **no secrets
are written to disk**. Copy the skeleton below, paste in your values, and run it
in the shell you'll use for Terraform:

```bash
# --- Azure service principal credentials (fill in all four) ---
export ARM_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx;        \
export ARM_CLIENT_SECRET=your-service-principal-secret;          \
export ARM_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx;        \
export ARM_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

> Where to find these: `ARM_CLIENT_ID` and `ARM_CLIENT_SECRET` come from your app
> registration's "Certificates & secrets"; `ARM_TENANT_ID` and
> `ARM_SUBSCRIPTION_ID` are on the subscription / tenant overview pages
> (`az account show` prints both if you have the Azure CLI).

### Step 2b — If all you have is a username, password, client ID, and secret

Temporary lab subscriptions (e.g. **A Cloud Guru / Real Hands-On Labs**) often
hand you just four things: a portal **username** + **password** and a service
principal **client ID** + **secret** — no tenant ID, no subscription ID, and a
**pre-created resource group** you're locked into. You can derive everything
else from those values. Paste the four into the block below and run it (needs
`curl` + `python3`):

```bash
# --- Paste the four values your lab gave you ---
LAB_USERNAME='cloud_user_xxxxx@realhandsonlabs.com'   # used only to find the tenant
export ARM_CLIENT_ID='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
export ARM_CLIENT_SECRET='your-service-principal-secret'
# (the portal password isn't needed below — the service principal is enough)

# --- Derive the tenant ID from the username's email domain ---
LAB_DOMAIN="${LAB_USERNAME##*@}"
export ARM_TENANT_ID=$(curl -s \
  "https://login.microsoftonline.com/${LAB_DOMAIN}/v2.0/.well-known/openid-configuration" \
  | python3 -c "import sys,json,re;print(re.search(r'/([0-9a-f-]{36})/',json.load(sys.stdin)['token_endpoint']).group(1))")

# --- Get a management token, then discover the subscription + resource group ---
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/${ARM_TENANT_ID}/oauth2/v2.0/token" \
  --data-urlencode "client_id=${ARM_CLIENT_ID}" \
  --data-urlencode "client_secret=${ARM_CLIENT_SECRET}" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "scope=https://management.azure.com/.default" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

export ARM_SUBSCRIPTION_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions?api-version=2020-01-01" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['value'][0]['subscriptionId'])")

export TF_VAR_existing_resource_group_name=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://management.azure.com/subscriptions/${ARM_SUBSCRIPTION_ID}/resourcegroups?api-version=2021-04-01" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['value'][0]['name'])")

echo "tenant=$ARM_TENANT_ID"
echo "subscription=$ARM_SUBSCRIPTION_ID"
echo "resource_group=$TF_VAR_existing_resource_group_name"
```

`TF_VAR_existing_resource_group_name` tells Terraform to deploy **into the lab's
existing resource group** instead of creating a new one (the lab SP isn't
allowed to create resource groups).

> **Region note:** lab subscriptions are usually restricted to a subset of
> regions for Postgres. If `terraform apply` fails with
> `LocationIsOfferRestricted`, pick another region:
> `export TF_VAR_location=eastus2` (then try `centralus`, `westus2`, …).
> The resource group's own region does **not** have to match the server's.

## Step 3 — Create the database with Terraform

```bash
cd terraform
terraform init
terraform apply        # review the plan, then type "yes"  (-auto-approve to skip)
cd ..
```

This provisions a burstable `B_Standard_B1ms` server with 32 GiB of storage and
a firewall rule. The admin password is randomly generated and kept in Terraform
state (gitignored) — read it back with `terraform output`.

## Step 4 — Create the container `.env` from Terraform outputs

The compose file reads connection details from `.env` (gitignored). Generate it
straight from the Terraform outputs:

```bash
cat > .env <<EOF
PG_HOST=$(terraform -chdir=terraform output -raw server_fqdn)
PG_USER=$(terraform -chdir=terraform output -raw admin_username)
PG_PASSWORD=$(terraform -chdir=terraform output -raw admin_password)
PG_DATABASE=$(terraform -chdir=terraform output -raw management_database)
EOF
```

Or copy `.env.example` to `.env` and fill it in by hand:

```bash
PG_HOST=your-server-name.postgres.database.azure.com
PG_USER=pgadmin
PG_PASSWORD=replace-with-terraform-admin_password
PG_DATABASE=postgres
```

## Step 5 — Start the stack

```bash
docker compose up --build -d
docker compose logs -f          # watch it come up; Ctrl-C to stop tailing
```

## Step 6 — Open Grafana

Browse to **http://localhost:3000**, log in with:

```
username: admin
password: admin
```

Open the **"Azure PostgreSQL Demo"** dashboard. You'll see:

- **Database storage used** — updates as soon as metrics arrive.
- **Queries per second (1m rate)** — a spike every 5 minutes when the `db-load`
  container runs its batch.

> The QPS panel can take a few minutes to show its first bar, and ~5 minutes
> between bars, because the load runs on a 5-minute interval by design. Lower
> `LOAD_INTERVAL_SECONDS` in `docker-compose.yml` if you want faster feedback
> while testing.

## Step 7 — Tear down

```bash
docker compose down -v
terraform -chdir=terraform destroy
```

---

## How it fits together

```
db-load ──queries──▶ Azure PostgreSQL Flexible Server
                            │
grafana-stack:              │ (Alloy postgres exporter scrapes over SSL)
   Alloy ──remote_write──▶ Mimir ──PromQL──▶ Grafana ──▶ http://localhost:3000
```

- **Storage** comes from the Postgres exporter metric `pg_database_size_bytes`.
- **Queries/sec** is `rate(pg_stat_database_xact_commit + …_xact_rollback [1m])`
  against the `postgres` database.

## Notes & caveats

- This is a **demo**, not production: Mimir runs single-node with local
  filesystem storage, the server firewall is opened wide (`0.0.0.0`–
  `255.255.255.255`) so the container host can connect, and Grafana uses the
  default `admin/admin` login. Tighten all of these for anything real.
- Terraform state contains the generated DB password in plaintext and is
  gitignored. Don't commit it.
- The container host's outbound IP must be allowed by the server firewall (the
  wide-open demo rule covers this). Azure requires SSL, which the connection
  strings already request (`sslmode=require`).
