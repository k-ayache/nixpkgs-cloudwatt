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

contrail-service-user:
	@docker run --rm -ti \
          --dns=172.18.10.10 --dns-search=dev0.loc.cloudwatt.net \
          --network=dockercompose_cloudwatt \
                -l SERVICE_IGNORE=1 \
                -e openstack_region=dev0 \
                -e VAULT_TOKEN \
                -e OPENSTACK_TOOLS_APPLICATIONS="opencontrail" \
          r.cwpriv.net/openstack/tools:latest create-service-users opencontrail
contrail-up: dev-consul-data dev-vault-data
	@docker-compose -f contrail.yml up
contrail-scale: dev-consul-data dev-vault-data
	@echo -e "\nAll services in contrail.yml will be recreated and api, control and discovery will be scaled ...\n"
	@docker-compose -f contrail.yml up --scale api=2 --scale control=2 --scale discovery=2

contrail-clean:
	@docker-compose -f contrail.yml down --volumes

contrail-provision:
	@./provision

contrail-test:
	@./check-contrail
gremlin-up:
	@docker-compose -f gremlin-server.yml up

gremlin-clean:
	@docker-compose -f gremlin-server.yml down --volumes

print-%:
	@echo '$($*)'
