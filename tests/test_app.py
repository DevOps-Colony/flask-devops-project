import pytest
import json
import sqlite3
from werkzeug.security import check_password_hash
import sys
import os

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

from app import app, get_db_connection

class TestBasicRoutes:
    def test_index_route(self, client):
        """Test the index route."""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Welcome' in response.data or b'Flask' in response.data

    def test_health_endpoint(self, client):
        """Test health check endpoint."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'

    def test_ready_endpoint(self, client):
        """Test readiness check endpoint."""
        response = client.get('/ready')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'ready'

class TestAuthentication:
    def test_register_page_loads(self, client):
        """Test that register page loads correctly."""
        response = client.get('/register')
        assert response.status_code == 200
        assert b'register' in response.data.lower() or b'sign up' in response.data.lower()

    def test_login_page_loads(self, client):
        """Test that login page loads correctly."""
        response = client.get('/login')
        assert response.status_code == 200
        assert b'login' in response.data.lower() or b'sign in' in response.data.lower()

    def test_successful_registration(self, client):
        """Test successful user registration."""
        response = client.post('/register', data={
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'NewPass123',
            'confirm_password': 'NewPass123'
        })
        assert response.status_code == 302  # Redirect after successful registration

    def test_successful_login(self, client):
        """Test successful user login."""
        # First register a user
        client.post('/register', data={
            'username': 'loginuser',
            'email': 'login@example.com',
            'password': 'LoginPass123',
            'confirm_password': 'LoginPass123'
        })
        
        # Then try to login
        response = client.post('/login', data={
            'username': 'loginuser',
            'password': 'LoginPass123'
        })
        assert response.status_code == 302  # Redirect after successful login

    def test_invalid_login(self, client):
        """Test login with invalid credentials."""
        response = client.post('/login', data={
            'username': 'nonexistent',
            'password': 'wrongpassword'
        })
        assert response.status_code == 400
        assert b'Invalid' in response.data or b'error' in response.data

    def test_dashboard_requires_login(self, client):
        """Test that dashboard requires authentication."""
        response = client.get('/dashboard')
        assert response.status_code == 302  # Redirect to login

    def test_dashboard_with_auth(self, authenticated_client):
        """Test dashboard access with authentication."""
        response = authenticated_client.get('/dashboard')
        assert response.status_code == 200
        assert b'dashboard' in response.data.lower() or b'welcome' in response.data.lower()

    def test_logout(self, authenticated_client):
        """Test user logout."""
        response = authenticated_client.get('/logout')
        assert response.status_code == 302  # Redirect after logout
        
        # Verify user is logged out by trying to access dashboard
        response = authenticated_client.get('/dashboard')
        assert response.status_code == 302  # Should redirect to login

class TestFormValidation:
    def test_register_empty_fields(self, client):
        """Test registration with empty fields."""
        response = client.post('/register', data={})
        assert response.status_code == 400  # Bad request for missing fields
        assert b'required' in response.data.lower() or b'error' in response.data.lower()

    def test_register_invalid_email(self, client):
        """Test registration with invalid email."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'invalid-email',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        assert response.status_code == 400
        assert b'valid email' in response.data.lower() or b'email' in response.data.lower()

    def test_register_weak_password(self, client):
        """Test registration with weak password."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'test@example.com',
            'password': '123',
            'confirm_password': '123'
        })
        assert response.status_code == 400
        assert b'password' in response.data.lower()

    def test_register_password_mismatch(self, client):
        """Test registration with password mismatch."""
        response = client.post('/register', data={
            'username': 'testuser',
            'email': 'test@example.com',
            'password': 'TestPass123',
            'confirm_password': 'DifferentPass123'
        })
        assert response.status_code == 400
        assert b'match' in response.data.lower() or b'password' in response.data.lower()

    def test_login_empty_fields(self, client):
        """Test login with empty fields."""
        response = client.post('/login', data={})
        assert response.status_code == 400  # Bad request for missing fields
        assert b'required' in response.data.lower() or b'error' in response.data.lower()

    def test_register_duplicate_username(self, client):
        """Test registration with duplicate username."""
        # Register first user
        client.post('/register', data={
            'username': 'duplicate',
            'email': 'first@example.com',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        
        # Try to register with same username
        response = client.post('/register', data={
            'username': 'duplicate',
            'email': 'second@example.com',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        assert response.status_code == 400
        assert b'already exists' in response.data.lower() or b'username' in response.data.lower()

    def test_register_duplicate_email(self, client):
        """Test registration with duplicate email."""
        # Register first user
        client.post('/register', data={
            'username': 'user1',
            'email': 'duplicate@example.com',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        
        # Try to register with same email
        response = client.post('/register', data={
            'username': 'user2',
            'email': 'duplicate@example.com',
            'password': 'TestPass123',
            'confirm_password': 'TestPass123'
        })
        assert response.status_code == 400
        assert b'already exists' in response.data.lower() or b'email' in response.data.lower()

class TestSecurity:
    def test_password_hashing(self, client):
        """Test that passwords are properly hashed."""
        # Register a user
        client.post('/register', data={
            'username': 'secureuser',
            'email': 'secure@example.com',
            'password': 'SecurePass123',
            'confirm_password': 'SecurePass123'
        })
        
        # Check that password is hashed in database
        conn = get_db_connection()
        user = conn.execute('SELECT password_hash FROM users WHERE username = ?', ('secureuser',)).fetchone()
        conn.close()
        
        assert user is not None
        # Password should be hashed, not plain text
        assert user['password_hash'] != 'SecurePass123'
        # Should be able to verify the password
        assert check_password_hash(user['password_hash'], 'SecurePass123')

    def test_session_management(self, client):
        """Test session management."""
        # Register and login
        client.post('/register', data={
            'username': 'sessionuser',
            'email': 'session@example.com',
            'password': 'SessionPass123',
            'confirm_password': 'SessionPass123'
        })
        
        response = client.post('/login', data={
            'username': 'sessionuser',
            'password': 'SessionPass123'
        }, follow_redirects=True)
        
        # User should be logged in and able to access dashboard
        response = client.get('/dashboard')
        assert response.status_code == 200

    def test_failed_login_attempts(self, client):
        """Test failed login attempt handling."""
        # Register a user
        client.post('/register', data={
            'username': 'failuser',
            'email': 'fail@example.com',
            'password': 'CorrectPass123',
            'confirm_password': 'CorrectPass123'
        })
        
        # Attempt login with wrong password
        response = client.post('/login', data={
            'username': 'failuser',
            'password': 'WrongPassword'
        })
        assert response.status_code == 400
        assert b'Invalid' in response.data or b'password' in response.data.lower()

class TestEndpoints:
    def test_nonexistent_route(self, client):
        """Test 404 for nonexistent routes."""
        response = client.get('/nonexistent')
        assert response.status_code == 404

    def test_health_check_content(self, client):
        """Test health check endpoint returns proper JSON."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'status' in data
        assert 'timestamp' in data
        assert data['status'] == 'healthy'

    def test_ready_check_content(self, client):
        """Test readiness check endpoint returns proper JSON."""
        response = client.get('/ready')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'status' in data
        assert 'timestamp' in data
        assert data['status'] == 'ready'

class TestUserFlow:
    def test_complete_user_flow(self, client):
        """Test complete user registration and login flow."""
        # Step 1: Register
        response = client.post('/register', data={
            'username': 'flowuser',
            'email': 'flow@example.com',
            'password': 'FlowPass123',
            'confirm_password': 'FlowPass123'
        })
        assert response.status_code == 302  # Redirect after successful registration
        
        # Step 2: Login
        response = client.post('/login', data={
            'username': 'flowuser',
            'password': 'FlowPass123'
        })
        assert response.status_code == 302  # Redirect after successful login
        
        # Step 3: Access Dashboard
        response = client.get('/dashboard')
        assert response.status_code == 200
        
        # Step 4: Logout
        response = client.get('/logout')
        assert response.status_code == 302  # Redirect after logout
        
        # Step 5: Verify logout
        response = client.get('/dashboard')
        assert response.status_code == 302  # Should redirect to login

    def test_redirect_after_logout(self, authenticated_client):
        """Test that user is redirected to login after logout."""
        response = authenticated_client.get('/logout')
        assert response.status_code == 302
        
        # Try to access protected page
        response = authenticated_client.get('/dashboard')
        assert response.status_code == 302  # Should redirect to login
