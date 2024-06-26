"""
Test raw http authorization interface.
"""

import pytest

pytestmark = [pytest.mark.authorino, pytest.mark.standalone_only]


def test_authorized_via_http(client, auth):
    """Test raw http authentication with Keycloak."""
    response = client.get("/check", auth=auth)
    assert response.status_code == 200
    assert response.text == ""
    assert response.headers.get("x-ext-auth-other-json", "") == '{"propX":"valueX"}'


def test_unauthorized_via_http(client):
    """Test raw http authentication with unauthorized request."""
    response = client.get("/check")
    assert response.status_code == 401
    assert response.text == ""
