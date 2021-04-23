IMAGE_NAME=sandklef/sandklef-scancode
CONTAINER_NAME=sandklef-scancode
TAG=$(shell grep "ENV SCANCODE_VERSION" Dockerfile | cut -d "=" -f 2)


check:
	@echo "IMAGE_NAME:     $(IMAGE_NAME)"
	@echo "CONTAINER_NAME: $(CONTAINER_NAME)"
	@echo "TAG:            $(TAG)"

run:
	docker run -it -v `pwd`/coding_project/:/scan --name $(CONTAINER_NAME) $(IMAGE_NAME):$(TAG) uname -a

build:
	docker build `pwd` -t $(IMAGE_NAME):$(TAG)

push:
	docker push $(IMAGE_NAME):$(TAG)
