"""
Tests base64 decoding abilities of Authorino and it's escaping of strings
"""

import json
from base64 import standard_b64encode

import pytest

from testsuite.policy.authorization import ValueFrom, JsonResponse

pytestmark = [pytest.mark.authorino]


@pytest.fixture(scope="module")
def authorization(authorization):
    """Add response to Authorization"""
    authorization.responses.add_success_header(
        "header", JsonResponse({"anything": ValueFrom("context.request.http.headers.test|@base64:decode")})
    )
    return authorization


@pytest.mark.parametrize(
    "string", ['My name is "John"', 'My name is "John', "My name is 'John'", "My name is 'John", '{"json": true}']
)
def test_base64(auth, client, string):
    """Tests that base64 decoding filter works"""
    encoded = standard_b64encode(string.encode()).decode()
    response = client.get("/get", auth=auth, headers={"test": encoded})
    assert response.status_code == 200

    data_list = response.json()["headers"].get("Header")
    assert data_list

    found_string = False
    for data_str in data_list:
        data = json.loads(data_str)  # Parse the JSON-formatted string
        if "anything" in data and data["anything"] == string:
            found_string = True
            break

    assert found_string
