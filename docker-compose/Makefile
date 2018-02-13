VAULT_TOKEN ?= vault-root-token

dev-consul-data:
	@docker run --rm -ti \
	  --dns=172.18.10.10 --dns-search=dev0.loc.cloudwatt.net \
	  --network=dockercompose_cloudwatt \
		-l SERVICE_IGNORE=1 \
	  -v $(shell pwd)/consul-data:/data \
		r.cwpriv.net/consul/agent:latest load-consul-data

dev-vault-data:
	@docker run --rm -ti \
	  --dns=172.18.10.10 --dns-search=dev0.loc.cloudwatt.net \
	  --network=dockercompose_cloudwatt \
		-l SERVICE_IGNORE=1 \
		-e VAULT_TOKEN \
	  -v $(shell pwd)/vault-data.yml:/vault-data.yml r.cwpriv.net/development/vault:latest \
		vaultctl --vault-addr https://vault.service:8200 sync -c /vault-data.yml

contrail-up: dev-consul-data dev-vault-data
	@docker-compose -f contrail.yml up

contrail-clean:
	@docker-compose -f contrail.yml down --volumes

contrail-provision: 
	@./provision; contrail-api-cli provision -f provision_file.json

gremlin-up:
	@docker-compose -f gremlin-server.yml up

gremlin-clean:
	@docker-compose -f gremlin-server.yml down --volumes

print-%:
	@echo '$($*)'
