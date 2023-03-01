#!/usr/bin/env bats

@test "docker file must pass lint" {
	cd src && docker run --log-driver=journald --rm -e HADOLINT_IGNORE=DL3047 -i hadolint/hadolint < ${DOCKER_FILE}
}
