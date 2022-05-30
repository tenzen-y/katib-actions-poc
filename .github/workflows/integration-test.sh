name: integration test
on:
  push:
    branches:
      - master
jobs:
  integration-test:
    runs-on: ubuntu-20.04
    strategy:
      matrix:
        cluster_version: ["1.22.5"]
        experiments:
          - hp-tuning/random.yaml
          - hp-tuning/grid.yaml
          - hp-tuning/bayesian-optimization.yaml
          - hp-tuning/tpe.yaml
          - hp-tuning/multivariate-tpe.yaml
          - hp-tuning/cma-es.yaml
          - hp-tuning/hyperband.yaml
          - nas/enas-cpu.yaml
          - nas/darts-cpu.yaml
          - kubeflow-training-operator/pytorchjob-mnist.yaml
          - kubeflow-training-operator/tfjob-mnist-with-summaries.yaml
          - metrics-collector/file-metrics-collector.yaml
          - metrics-collector/file-metrics-collector-with-json-format.yaml
          - resume-experiment/never-resume.yaml
          - resume-experiment/from-volume-resume.yaml
          - early-stopping/median-stop.yaml
          - early-stopping/median-stop-with-json-format.yaml
    steps:
      -
        name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: 0
      -
        name: Fetch
        run: git fetch --tags -f
      -
        name: Setup minikube
        uses: manusa/actions-setup-minikube@v2.4.2
        with:
          minikube version: "v1.24.0"
          kubernetes version: "${{ matrix.cluster_version }}"
          github token: "${{ secrets.GITHUB_TOKEN }}"
          driver: docker
      -
        name: Wait for starting minkube cluster
        run: |
          kubectl wait --for condition=ready --timeout=5m node minikube
          kubectl get nodes
      -
        name: Deploy training-operator
        run: |
          kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.4.0"
      -
        name: Deploy Katib
        run: |
          TIMEOUT=30m
          kubectl apply -k "github.com/kubeflow/katib.git/manifests/v1beta1/installs/katib-standalone?ref=v0.13.0"
          kubectl wait --for=condition=ready --timeout=${TIMEOUT} -l "katib.kubeflow.org/component in (controller,db-manager,mysql,ui)" -n kubeflow pod
          kubectl get pods -n kubeflow
      -
        name: Deploy Experiment
        run: |
          kubectl apply -f "https://raw.githubusercontent.com/kubeflow/katib/master/examples/${{ matrix.experiments }}"
          timeout 1800 kubectl get pods -n kubeflow -w
          kubectl describe experiment -n kubeflow
      -
        name: Teardown
        run: |
          kubectl delete -f "https://raw.githubusercontent.com/kubeflow/katib/master/examples/${{ matrix.experiments }}" --wait false
          kubectl delete -k "github.com/kubeflow/katib.git/manifests/v1beta1/installs/katib-standalone?ref=v0.13.0" --wait false
          kubectl delete -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.4.0" --wait false
