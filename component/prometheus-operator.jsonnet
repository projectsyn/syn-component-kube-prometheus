local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local com = import 'lib/commodore.libjsonnet';
// The hiera parameters for the component
local params = inv.parameters.kube_prometheus;

local kp =
  (import 'kube-prometheus/main.libsonnet') {
    values+:: {
      common+: {
        namespace: params.namespace,
      },
    },

    prometheusOperator+: com.makeMergeable(params.prometheus_operator.params),
  };

{
  ['10_prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.objectFields(kp.prometheusOperator)
}
