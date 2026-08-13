{ ... }:

let
  proxy = "http://127.0.0.1:7890";

  proxyEnvironment = {
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    http_proxy = proxy;
    https_proxy = proxy;

    NO_PROXY = "localhost,127.0.0.1,::1,.local";
    no_proxy = "localhost,127.0.0.1,::1,.local";
  };
in
{
  systemd.services.nix-daemon.environment = proxyEnvironment;
  systemd.services.docker.environment = proxyEnvironment;
}