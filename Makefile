all: fix build-n-push
php-cs-fixer:
	docker run --rm -v $(shell pwd):/data cytopia/php-cs-fixer fix

fix: php-cs-fixer

image_reference_devel:=ghcr.io/benzine-framework/bouncer:devel

build-n-push: fix
	docker build \
		--build-arg BUILD_DATE="$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")" \
		--build-arg GIT_SHA="$(shell git rev-parse HEAD)" \
		--build-arg GIT_BUILD_ID="$(shell git rev-parse --abbrev-ref HEAD)-$(shell git describe --tags --dirty --always | sed -e 's/^v//')" \
		--build-arg GIT_COMMIT_MESSAGE="$(shell git log -1 --pretty=%B | head -n1)" \
		--build-context php:cli=docker-image://ghcr.io/benzine-framework/php:cli-8.2 \
		--tag benzine/bouncer \
		--tag $(image_reference_devel) \
		--target bouncer \
		--progress plain \
			.
	docker push $(image_reference_devel)

test-as-service: clean
	docker build -t bouncer --target bouncer .
	docker build -t test-app-a --target test-app-a .
	docker build -t test-app-b --target test-app-b .
	-docker network create --driver overlay bouncer-test
	$(MAKE) start_bouncer
	$(MAKE) start_test_a
	$(MAKE) start_test_b
	docker service logs -f bouncer
start_test_a:
	docker service create \
		--network bouncer-test \
	  	--name test-app-a \
	  	--env BOUNCER_DOMAIN=test-a.local \
	  	--env BOUNCER_ALLOW_NON_SSL=yes \
	  	--publish 8081:80 \
	  	test-app-a
start_test_b:
	docker service create \
		--network bouncer-test \
	  	--name test-app-b \
	  	--env BOUNCER_DOMAIN=test-b.local \
	  	--env BOUNCER_ALLOW_NON_SSL=yes \
	  	--publish 8082:80 \
	  	test-app-b
start_bouncer:
	docker service create \
		--network bouncer-test \
		--name bouncer \
		--publish 8080:80 \
		--mount type=bind,destination=/var/run/docker.sock,source=/var/run/docker.sock \
		bouncer

clean:
	-docker service rm bouncer test-app-a test-app-b
	#-docker network rm bouncer-test
	#-docker image rm test-app-a test-app-b bouncer
