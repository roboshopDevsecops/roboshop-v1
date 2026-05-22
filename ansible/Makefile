ANSIBLE_USER     ?= ec2-user
ANSIBLE_PASSWORD ?= DevOps321
INVENTORY        ?= localhost,

ANSIBLE_COMMON = -i $(INVENTORY) \
	-e ansible_user=$(ANSIBLE_USER) \
	-e ansible_password=$(ANSIBLE_PASSWORD) \
	-e ansible_become=true

default:
	ansible-playbook $(ANSIBLE_COMMON) main.yml -e "COMPONENT=$(COMPONENT)"

# Run from jump box against a host by DNS name or IP
remote:
	ansible-playbook -i $(HOST), $(ANSIBLE_COMMON) \
		-e ansible_connection=ssh \
		main.yml -e "COMPONENT=$(COMPONENT)"

frontend:
	$(MAKE) default COMPONENT=frontend

mysql:
	$(MAKE) default COMPONENT=mysql

catalogue:
	$(MAKE) default COMPONENT=catalogue

mongodb:
	$(MAKE) default COMPONENT=mongodb

user:
	$(MAKE) default COMPONENT=user

valkey:
	$(MAKE) default COMPONENT=valkey

cart:
	$(MAKE) default COMPONENT=cart

shipping:
	$(MAKE) default COMPONENT=shipping

rabbitmq:
	$(MAKE) default COMPONENT=rabbitmq

payment:
	$(MAKE) default COMPONENT=payment

notification:
	$(MAKE) default COMPONENT=notification

orders:
	$(MAKE) default COMPONENT=orders

ratings:
	$(MAKE) default COMPONENT=ratings

databases: mysql mongodb valkey rabbitmq
apps: catalogue user cart shipping payment notification orders ratings
all: databases apps frontend
