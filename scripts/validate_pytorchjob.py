"""Validate PyTorchJob manifests against the Kubeflow Training Operator's own CRD schema."""

import sys
import urllib.request

import jsonschema
import yaml

CRD_URL = "https://raw.githubusercontent.com/kubeflow/training-operator/v1.9.4/manifests/base/crds/kubeflow.org_pytorchjobs.yaml"

crd = yaml.safe_load(urllib.request.urlopen(CRD_URL, timeout=30).read())  # noqa: S310 - pinned https URL
schema = next(v for v in crd["spec"]["versions"] if v["name"] == "v1")["schema"]["openAPIV3Schema"]
failed = False
for path in sys.argv[1:]:
    for doc in yaml.safe_load_all(open(path)):
        if doc and doc.get("kind") == "PyTorchJob":
            errors = list(jsonschema.Draft7Validator(schema).iter_errors(doc))
            for e in errors:
                print(f"{path}: {list(e.path)}: {e.message}")
            failed |= bool(errors)
            print(f"{path}: PyTorchJob/{doc['metadata']['name']}: {'INVALID' if errors else 'valid'}")
sys.exit(1 if failed else 0)
