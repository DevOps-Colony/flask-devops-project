import pytest
import tempfile
import os
from app.app import app, init_db

@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    # Create a temporary database file
    db_fd, app.config['DATABASE'] = tempfile.mkstemp()
    app.config['TESTING'] = True
    app.config['SECRET_KEY'] = 'test-secret-key'
    app.config['WTF_CSRF_ENABLED'] = False
    
    with app.test_client() as client:
        with app.app_context():
            init_db()
        yield client
    
    # Clean up
    os.close(db_fd)
    os.unlink(app.config['DATABASE'])

@pytest.fixture
def authenticated_client(client):
    """Create a test client with an authenticated user."""
    # Register a test user
    client.post('/register', data={
        'username': 'testuser',
        'email': 'test@example.com',
        'password': 'TestPassword123',
        'confirm_password': 'TestPassword123'
    })
    
    # Login the test user
    client.post('/login', data={
        'username': 'testuser',
        'password': 'TestPassword123'
    })
    
    return client
