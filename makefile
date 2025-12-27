ln:
	ln -sf ../../backend.tf backend.tf
	ln -sf ../../provider.tf provider.tf
	ln -sf ../../base_locals.tf base_locals.tf

init:
	terraform init -backend-config=backend.config

tunnel-comfy-local:
	cloudflared tunnel --url http://127.0.0.1:8000
