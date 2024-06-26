"""Module containing tests for Reconciliation of MGC policies"""

from testsuite.policy.dns_policy import DNSPolicy


def dns_policy(openshift, name, parent, issuer, labels: dict[str, str] = None):  # pylint: disable=unused-argument
    """DNSPolicy constructor to unify DNSPolicy and TLSPolicy signatures, so they could be parametrized"""
    return DNSPolicy.create_instance(openshift, name, parent, labels=labels)
