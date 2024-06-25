# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

test:
	mix test

test-document-ai:
	mix test.watch test/actions/document_ai_test.exs