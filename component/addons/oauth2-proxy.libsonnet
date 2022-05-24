local com = import 'lib/commodore.libjsonnet';

local defaults = {
  local defaults = self,

  image: 'quay.io/oauth2-proxy/oauth2-proxy:latest',

  proxyPort: 4180,

  ingress: {
    enabled: true,
    host: null,
    annotations: {},
    tls: {
      enabled: true,
      secretName: null,
    },
  },

  proxyEnv: {},
  proxyArgs: {
    upstream: 'http://127.0.0.1:9090',
    'http-address': '0.0.0.0:%s' % defaults.proxyPort,
    'silence-ping-logging': true,
    'skip-provider-button': true,
    'reverse-proxy': true,
  },
};

{
  local config = self,

  values+:: {
    prometheus+: {
      name+: '',
      namespace+: '',
      _oauth2Proxy+: {},
    },
  },

  local params = defaults + config.values.prometheus._oauth2Proxy,
  local oauthProxy = {
    name: 'oauth2-proxy',
    image: params.image,
    args: std.map(
      function(arg) '--%s=%s' % [ arg, params.proxyArgs[arg] ],
      std.objectFields(params.proxyArgs),
    ),
    env: com.envList(params.proxyEnv),
  },

  prometheus+: {
    prometheus+: {
      spec+: {
        listenLocal: true,
        containers+: [ oauthProxy ],
      },
    },

    service+: {
      metadata+: {
        name+: '',
      },
      spec+: {
        selector+: {
        },
      },
    },

    authService+: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata+: config.prometheus.service.metadata {
        name: config.prometheus.service.metadata.name + '-auth',
      },
      spec: {
        selector+: config.prometheus.service.spec.selector,
        ports+: [
          {
            name: 'web',
            port: params.proxyPort,
            targetPort: params.proxyPort,
          },
        ],
      },
    },

    [if params.ingress.enabled then 'authIngress']+: {
      local ingress = self,
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata+: {
        name: 'prometheus-' + config.values.prometheus.name,
        namespace: config.values.prometheus.namespace,
        annotations+: params.ingress.annotations,
      },
      spec+: {
        rules+: [
          {
            host: params.ingress.host,
            http: {
              paths: [
                {
                  backend: {
                    service: {
                      name: config.prometheus.service.metadata.name,
                      port: {
                        number: params.proxyPort,
                      },
                    },
                  },
                  path: '/',
                  pathType: 'Prefix',
                },
              ],
            },
          },
        ],
        tls:
          if params.ingress.tls.enabled then [
            {
              hosts: [ params.ingress.host ],
              secretName: if params.ingress.tls.secretName == null then ingress.metadata.name + '-tls' else params.ingress.tls.secretName,
            },
          ]
          else
            [],
      },
    },
  },
}
