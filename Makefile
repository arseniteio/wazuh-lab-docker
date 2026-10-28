# Power ENS lab. Each target only calls a script in scripts/, so the same steps
# work by hand, in GitLab CI or in GitHub Actions.

.PHONY: up down status seed manager build-plugin logs

up:            ## bring everything up (Wazuh, Power ENS, engine and agent)
	@bash scripts/up.sh

down:          ## destroy the lab containers, volumes and certificates
	@bash scripts/down.sh

status:        ## containers, agents and incoming facts
	@bash scripts/status.sh

seed:          ## repeat seeding and validation of the configuration
	@bash scripts/seed.sh

manager:       ## reinstall the manager side of OSCompliance
	@bash scripts/manager-setup.sh

build-plugin:  ## rebuild the zip from PLUGIN_SRC
	@bash scripts/build-plugin.sh

logs:          ## follow a service log: make logs S=agent-01
	@bash -c '. scripts/lib.sh; "$${COMPOSE[@]}" logs -f $(S)'
