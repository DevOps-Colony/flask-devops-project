import pytest
import tempfile
import os
import sys

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

from app import app, init_db

@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    # Create a temporary database file
    db_fd, db_path = tempfile.mkstemp(suffix='.db')
    
    # Configure app for testing
    app.config['TESTING'] = True
    app.config['DATABASE'] = db_path
    app.config['WTF_CSRF_ENABLED'] = False
    
    # Initialize the test database
    init_db()
    
    with app.test_client() as client:
        with app.app_context():
            yield client
    
    # Clean up
    os.close(db_fd)
    os.unlink(db_path)

@pytest.fixture
def authenticated_client(client):
    """Create a test client with an authenticated user."""
    # Register a test user
    client.post('/register', data={
        'username': 'testuser',
        'email': 'test@example.com',
        'password': 'TestPass123',
        'confirm_password': 'TestPass123'
    })
    
    # Log in the test user
    response = client.post('/login', data={
        'username': 'testuser',
        'password': 'TestPass123'
    })
    
    return client

@pytest.fixture
def app_context():
    """Create application context for testing."""
    with app.app_context():
        yield app
