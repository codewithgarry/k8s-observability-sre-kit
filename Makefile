# Requires: promtool, yq (mikefarah v4), kubectl, kubeconform
ALERTS := $(wildcard alerts/*.yaml)
RULES  := $(patsubst alerts/%.yaml,build/%.rules.yaml,$(ALERTS))

.PHONY: all rules check test validate clean

all: check test validate

build/%.rules.yaml: alerts/%.yaml
	@mkdir -p build
	yq '.spec' $< > $@

rules: $(RULES)

check: rules            ## syntax-check the rule groups
	promtool check rules $(RULES)

test: rules             ## run alert unit tests
	promtool test rules tests/*.test.yaml

validate:               ## schema-validate every Kubernetes manifest
	kubectl kustomize . | kubeconform -strict -summary \
	  -schema-location default \
	  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

clean:
	rm -rf build
