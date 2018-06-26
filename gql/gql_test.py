#!/usr/bin/python3

"""
Example of python-gql usage against Absinthe-GraphQL backend.
"""

from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
from pprint import PrettyPrinter
import uuid

def test_todos(client, pp):
    """
    Simple query with no variables.
    """
    try:
        todos_query = gql("""query AllTodos
    { todos { id title completed order insertedAt } }
    """)
        result = client.execute(todos_query)
        pp.pprint(result)
    except Exception as e:
        print(e)


def test_create_item(client, pp):
    """
    Mutation with variables.
    """
    try:
        create_item_mutation = gql("""mutation CreateTodo($input:TodoInput!)
    { createItem(input:$input) { id title completed order insertedAt } }
    """)
        vars = {
            'input': {
                'id': str(uuid.uuid4()),
                'title': 'Gql Test',
                'completed': False
            }
        }
        result = client.execute(create_item_mutation, variable_values=vars)
        pp.pprint(result)
    except Exception as e:
        print(e)


if __name__ == '__main__':
    # Absinthe talks in JSON only
    http = RequestsHTTPTransport('http://localhost:4000/api', use_json=True)

    # Absinthe supports schema queries, so enable validation against schema
    client = Client(transport=http, fetch_schema_from_transport=True)

    pp = PrettyPrinter(indent=4)
    test_todos(client, pp)
    test_create_item(client, pp)
