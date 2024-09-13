"""Module containing all gateway classes"""

from typing import Any

import openshift_client as oc

from testsuite.certificates import Certificate
from testsuite.gateway import Gateway
from testsuite.kubernetes.client import KubernetesClient
from testsuite.kubernetes import KubernetesObject
from testsuite.kuadrant.policy import Policy
from testsuite.utils import check_condition


class KuadrantGateway(KubernetesObject, Gateway):
    """Gateway object for Kuadrant"""

    @classmethod
    def create_instance(cls, cluster: KubernetesClient, name, hostname, labels, tls=False):
        """Creates new instance of Gateway"""

        model: dict[Any, Any] = {
            "apiVersion": "gateway.networking.k8s.io/v1beta1",
            "kind": "Gateway",
            "metadata": {"name": name, "labels": labels},
            "spec": {
                "gatewayClassName": "istio",
                "listeners": [
                    {
                        "name": "api",
                        "port": 80,
                        "protocol": "HTTP",
                        "hostname": hostname,
                        "allowedRoutes": {"namespaces": {"from": "All"}},
                    }
                ],
            },
        }

        if tls:
            model["spec"]["listeners"] = [
                {
                    "name": "api",
                    "port": 443,
                    "protocol": "HTTPS",
                    "hostname": hostname,
                    "allowedRoutes": {"namespaces": {"from": "All"}},
                    "tls": {
                        "mode": "Terminate",
                        "certificateRefs": [{"name": f"{name}-tls", "kind": "Secret"}],
                    },
                }
            ]

        return cls(model, context=cluster.context)

    def add_listener(self, name: str, hostname: str):
        """Adds new listener to the Gateway"""
        self.model.spec.listeners.append(
            {
                "name": name,
                "port": 80,
                "protocol": "HTTP",
                "hostname": hostname,
                "allowedRoutes": {"namespaces": {"from": "All"}},
            }
        )

    @property
    def service_name(self) -> str:
        return f"{self.name()}-istio"

    def external_ip(self) -> str:
        with self.context:
            return f"{self.refresh().model.status.addresses[0].value}:80"

    @property
    def cluster(self):
        """Hostname of the first listener"""
        return KubernetesClient.from_context(self.context)

    def is_ready(self):
        """Check the programmed status"""
        for condition in self.model.status.conditions:
            if condition.type == "Programmed" and condition.status == "True":
                return True
        return False

    def wait_for_ready(self, timeout: int = 10 * 60):
        """Waits for the gateway to be ready in the sense of is_ready(self)"""
        success = self.wait_until(lambda obj: self.__class__(obj.model).is_ready(), timelimit=timeout)
        assert success, "Gateway didn't get ready in time"

    def is_affected_by(self, policy: Policy) -> bool:
        """Returns True, if affected by status is found within the object for the specific policy"""
        for condition in self.model.status.conditions:
            if check_condition(
                condition,
                f"kuadrant.io/{policy.kind(lowercase=False)}Affected",
                "True",
                "Accepted",
                f"Object affected by {policy.kind(lowercase=False)} {policy.namespace()}/{policy.name()}",
            ):
                return True
        return False

    def get_tls_cert(self):
        if "tls" not in self.model.spec.listeners[0]:
            return None

        tls_cert_secret_name = self.cert_secret_name
        try:
            tls_cert_secret = self.cluster.get_secret(tls_cert_secret_name)
        except oc.OpenShiftPythonException as e:
            if "Expected a single object, but selected 0" in e.msg:
                raise oc.OpenShiftPythonException("TLS secret was not created") from None
            raise e
        tls_cert = Certificate(
            key=tls_cert_secret["tls.key"],
            certificate=tls_cert_secret["tls.crt"],
            chain=tls_cert_secret["ca.crt"] if "ca.crt" in tls_cert_secret else None,
        )
        return tls_cert

    def delete(self, ignore_not_found=True, cmd_args=None):
        res = super().delete(ignore_not_found, cmd_args)
        with self.cluster.context:
            # TLSPolicy does not delete certificates it creates
            oc.selector(f"secret/{self.cert_secret_name}").delete(ignore_not_found=True)
            # Istio does not delete ServiceAccount
            oc.selector(f"sa/{self.service_name}").delete(ignore_not_found=True)
        return res

    @property
    def cert_secret_name(self):
        """Returns name of the secret with generated TLS certificate"""
        return self.model.spec.listeners[0].tls.certificateRefs[0].name

    @property
    def reference(self):
        return {
            "group": "gateway.networking.k8s.io",
            "kind": "Gateway",
            "name": self.name(),
        }
