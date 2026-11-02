.PHONY: up down status seed manager build-plugin logs

up:
	@bash scripts/up.sh

down:
	@bash scripts/down.sh

status:
	@bash scripts/status.sh

seed:
	@bash scripts/seed.sh

manager:
	@bash scripts/manager-setup.sh

build-plugin:
	@bash scripts/build-plugin.sh

logs:
	@bash -c '. scripts/lib.sh; "$${COMPOSE[@]}" logs -f $(S)'
